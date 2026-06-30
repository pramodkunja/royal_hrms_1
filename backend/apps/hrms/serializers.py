import logging

from rest_framework import serializers

from .models import Expense, ExpenseReceipt

logger = logging.getLogger(__name__)

MAX_RECEIPT_SIZE   = 5 * 1024 * 1024
ALLOWED_MIME_TYPES = {'image/jpeg', 'image/png', 'application/pdf'}


class ExpenseReceiptSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model  = ExpenseReceipt
        fields = ['id', 'url']

    def get_url(self, obj: ExpenseReceipt) -> str | None:
        if not obj.file:
            return None
        request = self.context.get('request')
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url


class ExpenseSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    branch_name   = serializers.SerializerMethodField()
    receipts      = ExpenseReceiptSerializer(many=True, read_only=True)

    class Meta:
        model  = Expense
        fields = [
            'id', 'title', 'category', 'amount', 'expense_date',
            'description', 'status', 'receipts',
            'employee_name', 'branch_name', 'created_at',
        ]

    def get_employee_name(self, obj: Expense) -> str:
        return obj.employee.full_name if obj.employee_id else ''

    def get_branch_name(self, obj: Expense) -> str:
        return obj.branch.branch_name if obj.branch_id else ''


class ExpenseCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Expense
        fields = ['title', 'category', 'amount', 'expense_date', 'description']

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError('Amount must be greater than zero.')
        return value


def validate_receipt_file(file) -> None:
    if file.size > MAX_RECEIPT_SIZE:
        raise serializers.ValidationError(f'Each receipt must be under 5 MB.')
    content_type = getattr(file, 'content_type', '')
    if content_type not in ALLOWED_MIME_TYPES:
        raise serializers.ValidationError('Only PDF, JPG, and PNG receipts are accepted.')
