import logging

from django.core.paginator import Paginator
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from core.responses import error, first_error, get_client_ip, success

from apps.accounts.models import AuditLog, Company
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

        qs = Candidate.objects.select_related('interviewer', 'referral_by', 'added_by').all()

        if s := request.query_params.get('status'):
            if s in {Candidate.STATUS_PENDING, Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED}:
                qs = qs.filter(status=s)

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
        if new_status not in {Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED}:
            return error('status must be "selected" or "rejected".')

        if candidate.status != Candidate.STATUS_PENDING:
            return error(f'Candidate is already {candidate.status}.')

        remarks = request.data.get('remarks', '')
        candidate.status = new_status
        candidate.save(update_fields=['status', 'updated_at'])

        actor_name = request.user.full_name or request.user.email

        CandidateLog.objects.create(
            candidate=candidate,
            log_type=CandidateLog.TYPE_SUCCESS if new_status == 'selected' else CandidateLog.TYPE_ERROR,
            title=f'Interview conducted — marked as {new_status}',
            description=f'By {actor_name}. {remarks}'.strip('. '),
        )

        # Send automated email
        template_slug = 'selection' if new_status == 'selected' else 'rejection'
        email_status  = _send_candidate_email(candidate, template_slug, request.user)

        CandidateLog.objects.create(
            candidate=candidate,
            log_type=CandidateLog.TYPE_SUCCESS if email_status == 'sent' else CandidateLog.TYPE_WARN,
            title=f'{"Selection" if new_status == "selected" else "Rejection"} email sent',
            description=f'Using template: Interview {new_status.title()}',
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
            qs = qs.filter(candidate__name__icontains=q) | qs.filter(to_email__icontains=q)

        return success('Email logs retrieved.', data=CandidateEmailSerializer(qs, many=True).data)


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

