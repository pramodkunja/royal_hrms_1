import logging

from django.db import transaction
from django.db.models import Sum
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import AuditLog
from apps.branch.models import Branch, City, State
from apps.branch.serializers import BranchSerializer, CitySerializer, StateSerializer
from apps.branch.utils import generate_branch_code

logger = logging.getLogger('branch')


def _get_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR') or '0.0.0.0'


def _has_perm(user, codename):
    """Return True if the authenticated user's role carries the given permission codename."""
    if not user or not user.role:
        return False
    return user.role.role_permissions.filter(permission__codename=codename).exists()


def success(message, data=None, http_status=status.HTTP_200_OK):
    return Response(
        {'status': 'success', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


def error(message, data=None, http_status=status.HTTP_400_BAD_REQUEST):
    return Response(
        {'status': 'error', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


_PERM_DENIED = 'You do not have permission to perform this action.'


# ─── State & City (cascading dropdowns) ──────────────────────────────────────

class StateListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        states = State.objects.filter(is_active=True)
        return success('States retrieved successfully.', data=StateSerializer(states, many=True).data)


class CityListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, state_id):
        try:
            state = State.objects.get(pk=state_id, is_active=True)
        except State.DoesNotExist:
            return error('State not found.', http_status=status.HTTP_404_NOT_FOUND)
        cities = state.cities.filter(is_active=True)
        return success('Cities retrieved successfully.', data=CitySerializer(cities, many=True).data)


# ─── Branch code preview ──────────────────────────────────────────────────────

class BranchPreviewCodeView(APIView):
    """Returns what branch code would be generated for a given city (preview only)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'branches.create'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        city_id = request.query_params.get('city_id')
        if not city_id:
            return error('city_id query parameter is required.')
        try:
            city = City.objects.select_related('state').get(pk=city_id, is_active=True)
        except City.DoesNotExist:
            return error('City not found.', http_status=status.HTTP_404_NOT_FOUND)
        with transaction.atomic():
            code = generate_branch_code(city.name)
        return success(
            'Branch code preview generated.',
            data={'branch_code': code, 'city': city.name, 'state': city.state.name},
        )


# ─── Branch CRUD ──────────────────────────────────────────────────────────────

class BranchListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'branches.view'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        qs = Branch.objects.select_related('state', 'city').all()
        if status_filter := request.query_params.get('status'):
            qs = qs.filter(status=status_filter)
        if state_id := request.query_params.get('state'):
            qs = qs.filter(state_id=state_id)
        if city_id := request.query_params.get('city'):
            qs = qs.filter(city_id=city_id)
        return success('Branches retrieved successfully.', data=BranchSerializer(qs, many=True).data)

    def post(self, request):
        if not _has_perm(request.user, 'branches.create'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        serializer = BranchSerializer(data=request.data)
        if not serializer.is_valid():
            return error(
                list(serializer.errors.values())[0][0],
                data=serializer.errors,
            )
        branch = serializer.save()
        AuditLog.objects.create(
            user=request.user, action='branch_created', module='branch',
            object_id=str(branch.pk),
            changes={'branch_code': branch.branch_code, 'branch_name': branch.branch_name},
            ip_address=_get_ip(request),
        )
        logger.info('Branch "%s" created by %s', branch.branch_code, request.user.email)
        return success(
            'Branch created successfully.',
            data=BranchSerializer(branch).data,
            http_status=status.HTTP_201_CREATED,
        )


class BranchDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_branch(self, pk):
        try:
            return Branch.objects.select_related('state', 'city').get(pk=pk)
        except Branch.DoesNotExist:
            return None

    def get(self, request, pk):
        if not _has_perm(request.user, 'branches.view'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        branch = self._get_branch(pk)
        if not branch:
            return error('Branch not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Branch retrieved successfully.', data=BranchSerializer(branch).data)

    def put(self, request, pk):
        if not _has_perm(request.user, 'branches.edit'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        branch = self._get_branch(pk)
        if not branch:
            return error('Branch not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = BranchSerializer(branch, data=request.data)
        if not serializer.is_valid():
            return error(
                list(serializer.errors.values())[0][0],
                data=serializer.errors,
            )
        updated = serializer.save()
        AuditLog.objects.create(
            user=request.user, action='branch_updated', module='branch',
            object_id=str(updated.pk),
            changes={'branch_code': updated.branch_code, 'branch_name': updated.branch_name},
            ip_address=_get_ip(request),
        )
        logger.info('Branch "%s" updated by %s', updated.branch_code, request.user.email)
        return success('Branch updated successfully.', data=BranchSerializer(updated).data)

    def patch(self, request, pk):
        if not _has_perm(request.user, 'branches.edit'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        branch = self._get_branch(pk)
        if not branch:
            return error('Branch not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = BranchSerializer(branch, data=request.data, partial=True)
        if not serializer.is_valid():
            return error(
                list(serializer.errors.values())[0][0],
                data=serializer.errors,
            )
        updated = serializer.save()
        AuditLog.objects.create(
            user=request.user, action='branch_updated', module='branch',
            object_id=str(updated.pk),
            changes={'branch_code': updated.branch_code, 'branch_name': updated.branch_name},
            ip_address=_get_ip(request),
        )
        logger.info('Branch "%s" patched by %s', updated.branch_code, request.user.email)
        return success('Branch updated successfully.', data=BranchSerializer(updated).data)

    def delete(self, request, pk):
        if not _has_perm(request.user, 'branches.delete'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        branch = self._get_branch(pk)
        if not branch:
            return error('Branch not found.', http_status=status.HTTP_404_NOT_FOUND)
        code = branch.branch_code
        AuditLog.objects.create(
            user=request.user, action='branch_deleted', module='branch',
            object_id=str(branch.pk),
            changes={'branch_code': code, 'branch_name': branch.branch_name},
            ip_address=_get_ip(request),
        )
        branch.delete()
        logger.info('Branch "%s" deleted by %s', code, request.user.email)
        return success(f'Branch "{code}" deleted successfully.')


# ─── Stats ────────────────────────────────────────────────────────────────────

class BranchStatsView(APIView):
    """
    Returns dashboard counts:
      total_employees, total_branches, total_active_branches,
      total_inactive_branches, total_cities
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'branches.view'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        total_branches = Branch.objects.count()
        total_active = Branch.objects.filter(status=Branch.STATUS_ACTIVE).count()
        total_employees = (
            Branch.objects.aggregate(total=Sum('employees_count'))['total'] or 0
        )
        total_cities = Branch.objects.values('city').distinct().count()
        return success('Branch statistics retrieved successfully.', data={
            'total_employees': total_employees,
            'total_branches': total_branches,
            'total_active_branches': total_active,
            'total_inactive_branches': total_branches - total_active,
            'total_cities': total_cities,
        })


# ─── Distribution (bar graph) ─────────────────────────────────────────────────

class BranchDistributionView(APIView):
    """
    Returns employee count per branch for the bar chart.
    Response: [{"branch": "Bengaluru HQ", "employees": 4}, ...]
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not _has_perm(request.user, 'branches.view'):
            return error(_PERM_DENIED, http_status=status.HTTP_403_FORBIDDEN)
        branches = (
            Branch.objects
            .filter(status=Branch.STATUS_ACTIVE)
            .values('branch_name', 'branch_code', 'employees_count')
            .order_by('-employees_count')
        )
        data = [
            {
                'branch': b['branch_name'],
                'branch_code': b['branch_code'],
                'employees': b['employees_count'],
            }
            for b in branches
        ]
        return success('Employee distribution by branch retrieved successfully.', data=data)
