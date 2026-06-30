import logging
import secrets
import string

from django.core.paginator import Paginator
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from core.responses import error, first_error, get_client_ip, success

from apps.accounts.models import AuditLog, Company, User
from apps.accounts.utils import send_template_email
from .models import Candidate, CandidateEmail, CandidateLog
from .serializers import (
    CandidateCreateSerializer,
    CandidateDetailSerializer,
    CandidateEmailSerializer,
    CandidateListSerializer,
)

logger = logging.getLogger(__name__)


def _has_perm(user, codename):
    if not user or not user.role:
        return False
    return user.role.role_permissions.filter(permission__codename=codename).exists()



_DENIED = 'You do not have permission to perform this action.'

# ─── Email helper ─────────────────────────────────────────────────────────────

def _send_candidate_email(candidate, template_slug, actor, extra_context=None):
    company      = Company.objects.first()
    company_name = company.company_name if company else ''
    subject      = f'Your application update — {candidate.position_applied}'
    sent_status  = CandidateEmail.STATUS_FAILED

    context = {
        'candidate_name': candidate.name,
        'position':       candidate.position_applied,
        'company_name':   company_name,
    }
    if extra_context:
        context.update(extra_context)

    try:
        send_template_email(
            recipient_email=candidate.email,
            template_name=template_slug,
            context=context,
        )
        sent_status = CandidateEmail.STATUS_SENT
        logger.info('Sent %s email to %s for candidate %s', template_slug, candidate.email, candidate.id)
    except Exception as exc:
        logger.exception('Failed to send %s email: %s', template_slug, exc)

    CandidateEmail.objects.create(
        candidate=candidate,
        template_used=template_slug,
        subject=subject,
        to_email=candidate.email,
        status=sent_status,
        sent_by=actor,
    )
    return sent_status


# ─── Candidate List + Create ──────────────────────────────────────────────────

class CandidateListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = Candidate.objects.select_related('interviewer', 'referral_by', 'added_by', 'branch').all()

        if s := request.query_params.get('status'):
            if s in {Candidate.STATUS_PENDING, Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED}:
                qs = qs.filter(status=s)

        if b := request.query_params.get('branch'):
            try:
                qs = qs.filter(branch_id=int(b))
            except (ValueError, TypeError):
                pass

        if q := request.query_params.get('search'):
            qs = qs.filter(name__icontains=q) | qs.filter(email__icontains=q) | qs.filter(position_applied__icontains=q)

        try:
            page_num  = max(1, int(request.query_params.get('page', 1)))
            page_size = min(50, max(1, int(request.query_params.get('page_size', 10))))
        except (ValueError, TypeError):
            page_num, page_size = 1, 10

        paginator = Paginator(qs, page_size)
        page_obj  = paginator.get_page(page_num)

        return success('Candidates retrieved.', data={
            'count':       paginator.count,
            'page':        page_obj.number,
            'page_size':   page_size,
            'total_pages': paginator.num_pages,
            'results':     CandidateListSerializer(page_obj.object_list, many=True).data,
        })

    def post(self, request):
        if not _has_perm(request.user, 'recruitment.create'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        serializer = CandidateCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return error(first_error(serializer.errors), data=serializer.errors)

        with transaction.atomic():
            candidate = serializer.save(added_by=request.user)

            CandidateLog.objects.create(
                candidate=candidate,
                log_type=CandidateLog.TYPE_INFO,
                title='Added to interview list',
                description=f'Added by {request.user.full_name or request.user.email}',
            )
            AuditLog.objects.create(
                user=request.user, action='candidate_created', module='recruitment',
                object_id=str(candidate.pk),
                changes={'name': candidate.name, 'position': candidate.position_applied},
                ip_address=get_client_ip(request),
            )
        logger.info('Candidate %s created by %s', candidate.id, request.user.email)
        return success('Candidate added to interview list.', data=CandidateListSerializer(candidate).data,
                  http_status=status.HTTP_201_CREATED)


# ─── Candidate Detail ─────────────────────────────────────────────────────────

class CandidateDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get(self, pk):
        try:
            return Candidate.objects.select_related(
                'interviewer', 'referral_by', 'added_by'
            ).prefetch_related('logs').get(pk=pk)
        except Candidate.DoesNotExist:
            return None

    def get(self, request, pk):
        if not _has_perm(request.user, 'recruitment.view'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        candidate = self._get(pk)
        if not candidate:
            return error('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Candidate retrieved.', data=CandidateDetailSerializer(candidate).data)


# ─── Mark Selected / Rejected ─────────────────────────────────────────────────

class CandidateStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not _has_perm(request.user, 'recruitment.edit'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.get(pk=pk)
        except Candidate.DoesNotExist:
            return error('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        valid_statuses = {
            Candidate.STATUS_PENDING,
            Candidate.STATUS_SCREENING,
            Candidate.STATUS_INTERVIEW_SCHEDULED,
            Candidate.STATUS_INTERVIEW_DONE,
            Candidate.STATUS_SELECTED,
            Candidate.STATUS_REJECTED,
        }
        if new_status not in valid_statuses:
            return error(f'Invalid status. Choose from: {", ".join(sorted(valid_statuses))}.')

        if candidate.status == Candidate.STATUS_CONVERTED:
            return error('Cannot change status of a converted candidate.')

        remarks    = request.data.get('remarks', '')
        actor_name = request.user.full_name or request.user.email

        candidate.status = new_status
        candidate.save(update_fields=['status', 'updated_at'])

        CandidateLog.objects.create(
            candidate=candidate,
            log_type=(CandidateLog.TYPE_SUCCESS
                      if new_status not in (Candidate.STATUS_REJECTED,)
                      else CandidateLog.TYPE_ERROR),
            title=f'Status changed to {new_status.replace("_", " ").title()}',
            description=f'By {actor_name}. {remarks}'.strip('. '),
        )

        # Send email only for selected or rejected transitions
        if new_status in (Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED):
            default_slug  = 'selection' if new_status == Candidate.STATUS_SELECTED else 'rejection'
            template_slug = (request.data.get('template_name') or default_slug).strip()
            email_status  = _send_candidate_email(candidate, template_slug, request.user)
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=(CandidateLog.TYPE_SUCCESS
                          if email_status == CandidateEmail.STATUS_SENT
                          else CandidateLog.TYPE_WARN),
                title=('Notification email sent'
                       if email_status == CandidateEmail.STATUS_SENT
                       else 'Email failed — check SMTP settings'),
                description=f'Template: {template_slug}',
            )

        AuditLog.objects.create(
            user=request.user, action=f'candidate_{new_status}', module='recruitment',
            object_id=str(candidate.pk),
            changes={'name': candidate.name, 'status': new_status},
            ip_address=get_client_ip(request),
        )

        return success(
            f'{candidate.name} marked as {new_status}. Email sent.',
            data=CandidateListSerializer(candidate).data,
        )


# ─── HR Decision (Candidate Review) ──────────────────────────────────────────

class CandidateHRDecisionView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not _has_perm(request.user, 'recruitment.approve'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.get(pk=pk, status=Candidate.STATUS_SELECTED)
        except Candidate.DoesNotExist:
            return error('Candidate not found or not selected.', http_status=status.HTTP_404_NOT_FOUND)

        decision = request.data.get('decision')
        if decision not in {'approve', 'reject'}:
            return error('decision must be "approve" or "reject".')

        remarks    = request.data.get('remarks', '')
        actor_name = request.user.full_name or request.user.email

        if decision == 'approve':
            # Template selection: default to welcome_employee if not specified
            template_name = (request.data.get('template_name') or 'welcome_employee').strip()

            # Sanitize extra_context: only string-keyed, identifier-named entries
            raw_extra = request.data.get('extra_context') or {}
            extra_context = {}
            if isinstance(raw_extra, dict):
                for k, v in raw_extra.items():
                    if isinstance(k, str) and k.isidentifier() and len(k) <= 100:
                        extra_context[k] = str(v)[:2000]

            candidate.hr_approved = True
            candidate.save(update_fields=['hr_approved', 'updated_at'])
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=CandidateLog.TYPE_SUCCESS,
                title='HR Approved — Onboarded as Employee',
                description=f'Approved by {actor_name}. {remarks}'.strip('. '),
            )
            email_status = _send_candidate_email(candidate, template_name, request.user, extra_context)
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=(CandidateLog.TYPE_SUCCESS
                          if email_status == CandidateEmail.STATUS_SENT
                          else CandidateLog.TYPE_WARN),
                title=('Onboarding email sent'
                       if email_status == CandidateEmail.STATUS_SENT
                       else 'Onboarding email failed — check SMTP settings'),
                description=f'Using template: {template_name}',
            )
            msg = f'{candidate.name} approved and onboarded!'
        else:
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=CandidateLog.TYPE_WARN,
                title='HR requested revision',
                description=f'Remarks: {remarks or "Please recheck documents"}',
            )
            msg = 'Revision requested. Candidate notified.'

        AuditLog.objects.create(
            user=request.user, action=f'candidate_hr_{decision}d', module='recruitment',
            object_id=str(candidate.pk),
            changes={'name': candidate.name, 'decision': decision},
            ip_address=get_client_ip(request),
        )

        return success(msg, data=CandidateDetailSerializer(candidate).data)


# ─── Candidate Review list (selected only, with logs) ─────────────────────────

class CandidateReviewListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = (Candidate.objects
              .filter(status=Candidate.STATUS_SELECTED)
              .select_related('interviewer', 'added_by')
              .prefetch_related('logs')
              .order_by('-updated_at'))

        try:
            page_num  = max(1, int(request.query_params.get('page', 1)))
            page_size = min(50, max(1, int(request.query_params.get('page_size', 10))))
        except (ValueError, TypeError):
            page_num, page_size = 1, 10

        paginator = Paginator(qs, page_size)
        page_obj  = paginator.get_page(page_num)

        return success('Selected candidates retrieved.', data={
            'count':       paginator.count,
            'page':        page_obj.number,
            'page_size':   page_size,
            'total_pages': paginator.num_pages,
            'results':     CandidateDetailSerializer(page_obj.object_list, many=True).data,
        })


# ─── Email Logs ────────────────────────────────────────────────────────────────

class CandidateEmailLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = (CandidateEmail.objects
              .select_related('candidate', 'sent_by')
              .order_by('-sent_at'))

        if q := request.query_params.get('search'):
            if len(q) > 100:
                return error('search must be 100 characters or fewer.')
            qs = qs.filter(candidate__name__icontains=q) | qs.filter(to_email__icontains=q)

        try:
            page_num  = max(1, int(request.query_params.get('page', 1)))
            page_size = min(50, max(1, int(request.query_params.get('page_size', 20))))
        except (ValueError, TypeError):
            page_num, page_size = 1, 20

        paginator = Paginator(qs, page_size)
        page_obj  = paginator.get_page(page_num)

        return success('Email logs retrieved.', data={
            'count':       paginator.count,
            'page':        page_obj.number,
            'page_size':   page_size,
            'total_pages': paginator.num_pages,
            'results':     CandidateEmailSerializer(page_obj.object_list, many=True).data,
        })


# ─── Stats ─────────────────────────────────────────────────────────────────────

class CandidateStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        total    = Candidate.objects.count()
        pending  = Candidate.objects.filter(status=Candidate.STATUS_PENDING).count()
        selected = Candidate.objects.filter(status=Candidate.STATUS_SELECTED).count()
        rejected = Candidate.objects.filter(status=Candidate.STATUS_REJECTED).count()
        pending_review = Candidate.objects.filter(
            status=Candidate.STATUS_SELECTED, details_filled=True, hr_approved=False
        ).count()

        return success('Recruitment stats retrieved.', data={
            'total': total, 'pending': pending,
            'selected': selected, 'rejected': rejected,
            'pending_review': pending_review,
        })


# ─── Send Portal Login (candidate onboarding invite) ──────────────────────────

class SendPortalLoginView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        if not _has_perm(request.user, 'recruitment.edit'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.select_for_update().get(pk=pk)
        except Candidate.DoesNotExist:
            return error('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)

        if candidate.status not in (
            Candidate.STATUS_SELECTED,
            Candidate.STATUS_INTERVIEW_DONE,
        ):
            return error('Candidate must be at least at Interview Done stage before sending portal login.')

        if candidate.portal_credentials_sent and candidate.portal_user_id:
            return error('Portal login already sent. Use resend if you want to issue new credentials.')

        if not candidate.email or not candidate.email.strip():
            return error('Candidate does not have a valid email address.')

        if User.objects.filter(email__iexact=candidate.email).exists():
            return error(
                'A portal account already exists for this email address.',
                http_status=status.HTTP_409_CONFLICT,
            )

        # portal_url: request body overrides company setting
        portal_url_override = (request.data.get('portal_url') or '').strip()
        if portal_url_override and not portal_url_override.startswith(('http://', 'https://')):
            return error('portal_url must start with http:// or https://.')

        # Generate a temporary password
        alphabet = string.ascii_letters + string.digits
        temp_password = ''.join(secrets.choice(alphabet) for _ in range(12))

        # Create portal user account
        portal_user = User.objects.create_user(
            email            = candidate.email,
            password         = temp_password,
            full_name        = candidate.name,
            must_change_password = True,
            onboarding_status    = User.ONBOARDING_PENDING,
        )

        candidate.portal_user             = portal_user
        candidate.portal_credentials_sent = True
        candidate.status                  = Candidate.STATUS_OFFER_SENT
        candidate.save(update_fields=['portal_user', 'portal_credentials_sent', 'status', 'updated_at'])

        CandidateLog.objects.create(
            candidate=candidate,
            log_type=CandidateLog.TYPE_INFO,
            title='Portal login sent',
            description=f'Account created for {candidate.email}. Sent by {request.user.full_name or request.user.email}.',
        )

        # Send credentials email
        company      = Company.objects.first()
        company_name = company.company_name if company else ''
        portal_url   = portal_url_override or (company.portal_url if company else '') or ''
        context = {
            'candidate_name': candidate.name,
            'position':       candidate.position_applied,
            'company_name':   company_name,
            'login_email':    candidate.email,
            'temp_password':  temp_password,
            'portal_url':     portal_url,
        }
        sent_status = CandidateEmail.STATUS_FAILED
        try:
            send_template_email(
                recipient_email=candidate.email,
                template_name='portal_invite',
                context=context,
            )
            sent_status = CandidateEmail.STATUS_SENT
        except Exception as exc:
            logger.exception('Failed to send portal invite to %s: %s', candidate.email, exc)

        CandidateEmail.objects.create(
            candidate=candidate,
            template_used='portal_invite',
            subject=f'Your Portal Login — {company_name}',
            to_email=candidate.email,
            status=sent_status,
            sent_by=request.user,
        )
        CandidateLog.objects.create(
            candidate=candidate,
            log_type=(CandidateLog.TYPE_SUCCESS
                      if sent_status == CandidateEmail.STATUS_SENT
                      else CandidateLog.TYPE_WARN),
            title=('Portal invite email sent'
                   if sent_status == CandidateEmail.STATUS_SENT
                   else 'Portal invite email failed — check SMTP settings'),
            description=f'To: {candidate.email}',
        )
        AuditLog.objects.create(
            user=request.user, action='portal_login_sent', module='recruitment',
            object_id=str(candidate.pk),
            changes={'email': candidate.email},
            ip_address=get_client_ip(request),
        )
        return success('Portal login sent successfully.', data={'email': candidate.email})


# ─── Resend Portal Login ───────────────────────────────────────────────────────

class ResendPortalLoginView(APIView):
    """
    POST /api/recruitment/candidates/<pk>/resend-portal-login/
    Issues a fresh temporary password to the candidate's existing portal account
    and re-sends the invitation email.  Only valid once credentials have been sent.
    """
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        if not _has_perm(request.user, 'recruitment.edit'):
            return error(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.select_for_update().get(pk=pk)
        except Candidate.DoesNotExist:
            return error('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)

        if not candidate.portal_credentials_sent or not candidate.portal_user_id:
            return error(
                'Portal login has not been sent yet. Use Send Portal Login first.',
                http_status=status.HTTP_400_BAD_REQUEST,
            )

        portal_user = candidate.portal_user
        if not portal_user:
            return error('Linked portal user account no longer exists.')

        if portal_user.onboarding_status == User.ONBOARDING_COMPLETE:
            return error('This candidate has already completed onboarding and cannot receive new credentials.')

        # Generate and set a fresh temporary password
        alphabet      = string.ascii_letters + string.digits
        temp_password = ''.join(secrets.choice(alphabet) for _ in range(12))
        portal_user.set_password(temp_password)
        portal_user.must_change_password = True
        portal_user.save(update_fields=['password', 'must_change_password'])

        company      = Company.objects.first()
        company_name = company.company_name if company else ''
        portal_url_override = (request.data.get('portal_url') or '').strip()
        if portal_url_override and not portal_url_override.startswith(('http://', 'https://')):
            return error('portal_url must start with http:// or https://.')
        portal_url = portal_url_override or (company.portal_url if company else '') or ''

        context = {
            'candidate_name': candidate.name,
            'position':       candidate.position_applied,
            'company_name':   company_name,
            'login_email':    candidate.email,
            'temp_password':  temp_password,
            'portal_url':     portal_url,
        }
        sent_status = CandidateEmail.STATUS_FAILED
        try:
            send_template_email(
                recipient_email=candidate.email,
                template_name='portal_invite',
                context=context,
            )
            sent_status = CandidateEmail.STATUS_SENT
        except Exception as exc:
            logger.exception('Failed to resend portal invite to %s: %s', candidate.email, exc)

        CandidateEmail.objects.create(
            candidate=candidate,
            template_used='portal_invite',
            subject=f'Your Portal Login (Resent) — {company_name}',
            to_email=candidate.email,
            status=sent_status,
            sent_by=request.user,
        )
        CandidateLog.objects.create(
            candidate=candidate,
            log_type=(CandidateLog.TYPE_SUCCESS
                      if sent_status == CandidateEmail.STATUS_SENT
                      else CandidateLog.TYPE_WARN),
            title=('Portal credentials resent'
                   if sent_status == CandidateEmail.STATUS_SENT
                   else 'Portal credentials resend failed — check SMTP settings'),
            description=f'New credentials issued to {candidate.email} by {request.user.full_name or request.user.email}.',
        )
        AuditLog.objects.create(
            user=request.user, action='portal_login_resent', module='recruitment',
            object_id=str(candidate.pk),
            changes={'email': candidate.email},
            ip_address=get_client_ip(request),
        )
        return success('Portal credentials resent successfully.', data={'email': candidate.email})

