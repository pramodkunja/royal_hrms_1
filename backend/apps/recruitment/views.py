import logging

from django.core.mail import send_mail
from django.template import Context, Template
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import AuditLog, EmailTemplate
from .models import Candidate, CandidateEmail, CandidateLog
from .serializers import (
    CandidateCreateSerializer,
    CandidateDetailSerializer,
    CandidateEmailSerializer,
    CandidateListSerializer,
)

logger = logging.getLogger('accounts')


def _has_perm(user, codename):
    if not user or not user.role:
        return False
    return user.role.role_permissions.filter(permission__codename=codename).exists()


def _get_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR') or '0.0.0.0'


def ok(message, data=None, http_status=status.HTTP_200_OK):
    return Response({'status': 'success', 'message': message, 'data': data if data is not None else {}}, status=http_status)


def err(message, data=None, http_status=status.HTTP_400_BAD_REQUEST):
    return Response({'status': 'error', 'message': message, 'data': data if data is not None else {}}, status=http_status)


_DENIED = 'You do not have permission to perform this action.'

# ─── Email helper ─────────────────────────────────────────────────────────────

def _send_candidate_email(candidate, template_slug, actor):
    """
    Renders the EmailTemplate with the given slug and sends it.
    Returns (subject, status_str) regardless of success/failure.
    """
    try:
        tmpl = EmailTemplate.objects.get(template_type=template_slug)
        context_data = {
            'candidate_name': candidate.name,
            'position':       candidate.position_applied,
            'company_name':   'Royal Staffing Services LLP',
        }
        subject = Template(tmpl.subject).render(Context(context_data))
        body    = Template(tmpl.body).render(Context(context_data))
        send_mail(subject, body, None, [candidate.email], html_message=body, fail_silently=True)
        sent_status = CandidateEmail.STATUS_SENT
        logger.info('Sent %s email to %s for candidate %s', template_slug, candidate.email, candidate.id)
    except EmailTemplate.DoesNotExist:
        subject     = f'Your application update — {candidate.position_applied}'
        sent_status = CandidateEmail.STATUS_SENT
    except Exception as exc:
        logger.exception('Failed to send %s email: %s', template_slug, exc)
        subject     = f'Your application update — {candidate.position_applied}'
        sent_status = CandidateEmail.STATUS_FAILED

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
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = Candidate.objects.select_related('interviewer', 'referral_by', 'added_by').all()

        if s := request.query_params.get('status'):
            if s in {Candidate.STATUS_PENDING, Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED}:
                qs = qs.filter(status=s)

        if q := request.query_params.get('search'):
            qs = qs.filter(name__icontains=q) | qs.filter(email__icontains=q) | qs.filter(position_applied__icontains=q)

        return ok('Candidates retrieved.', data=CandidateListSerializer(qs, many=True).data)

    def post(self, request):
        if not _has_perm(request.user, 'recruitment.create'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        serializer = CandidateCreateSerializer(data=request.data)
        if not serializer.is_valid():
            first = next(iter(serializer.errors.values()))[0]
            return err(str(first), data=serializer.errors)

        candidate = serializer.save(added_by=request.user)

        CandidateLog.objects.create(
            candidate=candidate,
            log_type=CandidateLog.TYPE_INFO,
            title='Added to interview list',
            description=f'Added by {request.user.get_full_name() or request.user.email}',
        )
        AuditLog.objects.create(
            user=request.user, action='candidate_created', module='recruitment',
            object_id=str(candidate.pk),
            changes={'name': candidate.name, 'position': candidate.position_applied},
            ip_address=_get_ip(request),
        )
        logger.info('Candidate %s created by %s', candidate.id, request.user.email)
        return ok('Candidate added to interview list.', data=CandidateListSerializer(candidate).data,
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
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        candidate = self._get(pk)
        if not candidate:
            return err('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)
        return ok('Candidate retrieved.', data=CandidateDetailSerializer(candidate).data)


# ─── Mark Selected / Rejected ─────────────────────────────────────────────────

class CandidateStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not _has_perm(request.user, 'recruitment.edit'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.get(pk=pk)
        except Candidate.DoesNotExist:
            return err('Candidate not found.', http_status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        if new_status not in {Candidate.STATUS_SELECTED, Candidate.STATUS_REJECTED}:
            return err('status must be "selected" or "rejected".')

        if candidate.status != Candidate.STATUS_PENDING:
            return err(f'Candidate is already {candidate.status}.')

        remarks = request.data.get('remarks', '')
        candidate.status = new_status
        candidate.save(update_fields=['status', 'updated_at'])

        actor_name = request.user.get_full_name() or request.user.email

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
            ip_address=_get_ip(request),
        )

        return ok(
            f'{candidate.name} marked as {new_status}. Email sent.',
            data=CandidateListSerializer(candidate).data,
        )


# ─── HR Decision (Candidate Review) ──────────────────────────────────────────

class CandidateHRDecisionView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if not _has_perm(request.user, 'recruitment.approve'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        try:
            candidate = Candidate.objects.get(pk=pk, status=Candidate.STATUS_SELECTED)
        except Candidate.DoesNotExist:
            return err('Candidate not found or not selected.', http_status=status.HTTP_404_NOT_FOUND)

        decision = request.data.get('decision')
        if decision not in {'approve', 'reject'}:
            return err('decision must be "approve" or "reject".')

        remarks    = request.data.get('remarks', '')
        actor_name = request.user.get_full_name() or request.user.email

        if decision == 'approve':
            candidate.hr_approved = True
            candidate.save(update_fields=['hr_approved', 'updated_at'])
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=CandidateLog.TYPE_SUCCESS,
                title='HR Approved — Onboarded as Employee',
                description=f'Approved by {actor_name}. {remarks}'.strip('. '),
            )
            _send_candidate_email(candidate, 'welcome_employee', request.user)
            CandidateLog.objects.create(
                candidate=candidate,
                log_type=CandidateLog.TYPE_SUCCESS,
                title='Welcome Employee email sent',
                description='Using template: Welcome Employee',
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
            ip_address=_get_ip(request),
        )

        return ok(msg, data=CandidateDetailSerializer(candidate).data)


# ─── Candidate Review list (selected only, with logs) ─────────────────────────

class CandidateReviewListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = (Candidate.objects
              .filter(status=Candidate.STATUS_SELECTED)
              .select_related('interviewer', 'added_by')
              .prefetch_related('logs')
              .order_by('-updated_at'))

        return ok('Selected candidates retrieved.', data=CandidateDetailSerializer(qs, many=True).data)


# ─── Email Logs ────────────────────────────────────────────────────────────────

class CandidateEmailLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        qs = (CandidateEmail.objects
              .select_related('candidate', 'sent_by')
              .order_by('-sent_at'))

        if q := request.query_params.get('search'):
            qs = qs.filter(candidate__name__icontains=q) | qs.filter(to_email__icontains=q)

        return ok('Email logs retrieved.', data=CandidateEmailSerializer(qs, many=True).data)


# ─── Stats ─────────────────────────────────────────────────────────────────────

class CandidateStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'recruitment.view'):
            return err(_DENIED, http_status=status.HTTP_403_FORBIDDEN)

        total    = Candidate.objects.count()
        pending  = Candidate.objects.filter(status=Candidate.STATUS_PENDING).count()
        selected = Candidate.objects.filter(status=Candidate.STATUS_SELECTED).count()
        rejected = Candidate.objects.filter(status=Candidate.STATUS_REJECTED).count()
        pending_review = Candidate.objects.filter(
            status=Candidate.STATUS_SELECTED, details_filled=True, hr_approved=False
        ).count()

        return ok('Recruitment stats retrieved.', data={
            'total': total, 'pending': pending,
            'selected': selected, 'rejected': rejected,
            'pending_review': pending_review,
        })
