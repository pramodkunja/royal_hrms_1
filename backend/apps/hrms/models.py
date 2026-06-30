import uuid
import logging

from django.db import models

logger = logging.getLogger(__name__)

CATEGORY_TRAVEL    = 'travel'
CATEGORY_MEALS     = 'meals'
CATEGORY_EQUIPMENT = 'equipment'
CATEGORY_OTHER     = 'other'

STATUS_PENDING  = 'pending'
STATUS_APPROVED = 'approved'
STATUS_REJECTED = 'rejected'


class Expense(models.Model):
    CATEGORY_CHOICES = [
        (CATEGORY_TRAVEL,    'Travel'),
        (CATEGORY_MEALS,     'Meals'),
        (CATEGORY_EQUIPMENT, 'Equipment'),
        (CATEGORY_OTHER,     'Other'),
    ]
    STATUS_CHOICES = [
        (STATUS_PENDING,  'Pending'),
        (STATUS_APPROVED, 'Approved'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    employee     = models.ForeignKey(
        'accounts.User',
        on_delete=models.CASCADE,
        related_name='expenses',
    )
    branch       = models.ForeignKey(
        'branch.Branch',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='expenses',
    )
    title        = models.CharField(max_length=200)
    category     = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    amount       = models.DecimalField(max_digits=10, decimal_places=2)
    expense_date = models.DateField()
    description  = models.TextField(blank=True, default='')
    status       = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'hrms_expense'
        ordering = ['-created_at']

    def __str__(self) -> str:
        return f'{self.title} — {self.employee.full_name}'


class ExpenseReceipt(models.Model):
    id         = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    expense    = models.ForeignKey(Expense, on_delete=models.CASCADE, related_name='receipts')
    file       = models.FileField(upload_to='expenses/receipts/')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hrms_expense_receipt'

    def __str__(self) -> str:
        return f'Receipt for {self.expense.title}'
