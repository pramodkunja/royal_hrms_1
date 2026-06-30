import logging

from django.db.models import Count, Q, Sum
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from core.responses import error, first_error, success

from ..models import Expense, ExpenseReceipt
from ..serializers import (
    ExpenseCreateSerializer,
    ExpenseSerializer,
    validate_receipt_file,
)

logger = logging.getLogger(__name__)


def _has_perm(user, codename: str) -> bool:
    if not user or not user.role:
        return False
    return user.role.role_permissions.filter(permission__codename=codename).exists()


def _resolve_branch(user):
    branch_name = getattr(user, 'branch', None)
    if not branch_name:
        return None
    from apps.branch.models import Branch
    return Branch.objects.filter(branch_name__iexact=branch_name).first()


class ExpenseListCreateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        has_approve = _has_perm(request.user, 'expenses.approve')
        queryset = (
            Expense.objects.select_related('employee', 'branch')
                           .prefetch_related('receipts')
                           .all()
            if has_approve
            else Expense.objects.select_related('employee', 'branch')
                                .prefetch_related('receipts')
                                .filter(employee=request.user)
        )

        branch = request.query_params.get('branch')
        if branch:
            queryset = queryset.filter(branch_id=branch)

        category = request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)

        status_param = request.query_params.get('status')
        if status_param:
            queryset = queryset.filter(status=status_param)

        serializer = ExpenseSerializer(queryset, many=True, context={'request': request})
        return success('Expenses retrieved.', serializer.data)

    def post(self, request):
        receipt_files = request.FILES.getlist('receipts')
        if not receipt_files:
            return error('At least one receipt is required.')

        for receipt_file in receipt_files:
            try:
                validate_receipt_file(receipt_file)
            except Exception as exc:
                return error(str(exc))

        serializer = ExpenseCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return error(first_error(serializer.errors))

        branch  = _resolve_branch(request.user)
        expense = serializer.save(employee=request.user, branch=branch)

        for receipt_file in receipt_files:
            ExpenseReceipt.objects.create(expense=expense, file=receipt_file)

        logger.info('Expense submitted: %s by %s (%d receipts)', expense.title, request.user.email, len(receipt_files))

        out = ExpenseSerializer(
            Expense.objects.select_related('employee', 'branch')
                           .prefetch_related('receipts')
                           .get(pk=expense.pk),
            context={'request': request},
        )
        return success('Expense submitted successfully.', out.data, http_status=status.HTTP_201_CREATED)


class ExpenseStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        has_approve = _has_perm(request.user, 'expenses.approve')
        queryset = (
            Expense.objects.all()
            if has_approve
            else Expense.objects.filter(employee=request.user)
        )

        stats = queryset.aggregate(
            total           = Count('id'),
            pending_count   = Count('id', filter=Q(status='pending')),
            approved_count  = Count('id', filter=Q(status='approved')),
            rejected_count  = Count('id', filter=Q(status='rejected')),
            total_amount    = Sum('amount'),
            pending_amount  = Sum('amount', filter=Q(status='pending')),
            approved_amount = Sum('amount', filter=Q(status='approved')),
        )

        return success('Stats retrieved.', {
            'total':           stats['total']           or 0,
            'pending':         stats['pending_count']   or 0,
            'approved':        stats['approved_count']  or 0,
            'rejected':        stats['rejected_count']  or 0,
            'total_amount':    float(stats['total_amount']    or 0),
            'pending_amount':  float(stats['pending_amount']  or 0),
            'approved_amount': float(stats['approved_amount'] or 0),
        })
