from django.urls import path
from apps.accounts.views import (
    AuditLogListView,
    CompanyRetrieveUpdateView,
    DepartmentDetailView,
    DepartmentListCreateView,
    DesignationDetailView,
    DesignationListCreateView,
    LoginView,
    LogoutView,
    TokenRefreshAPIView,
    ForgotPasswordView,
    VerifyOTPView,
    ResetPasswordView,
    ChangePasswordView,
    RoleListCreateView,
    RoleDetailView,
    PermissionListView,
    PermissionDetailView,
    SMTPSettingsListCreateView,
    SMTPSettingsDetailView,
    SMTPActivateView,
    SMTPTestEmailView,
    EmailTemplateListCreateView,
    EmailTemplateDetailView,
    EmailTemplatePreviewView,
)

urlpatterns = [
    # Auth
    path('login/',           LoginView.as_view(),          name='login'),
    path('logout/',          LogoutView.as_view(),          name='logout'),
    path('token/refresh/',   TokenRefreshAPIView.as_view(), name='token-refresh'),
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot-password'),
    path('verify-otp/',      VerifyOTPView.as_view(),       name='verify-otp'),
    path('reset-password/',  ResetPasswordView.as_view(),   name='reset-password'),
    path('change-password/', ChangePasswordView.as_view(),  name='change-password'),

    # Organisation structure
    path('departments/',           DepartmentListCreateView.as_view(), name='department-list'),
    path('departments/<int:pk>/',  DepartmentDetailView.as_view(),     name='department-detail'),
    path('designations/',          DesignationListCreateView.as_view(), name='designation-list'),
    path('designations/<int:pk>/', DesignationDetailView.as_view(),     name='designation-detail'),

    # Roles
    path('roles/',         RoleListCreateView.as_view(), name='role-list-create'),
    path('roles/<int:pk>/', RoleDetailView.as_view(),    name='role-detail'),

    # Permissions
    path('permissions/',         PermissionListView.as_view(),   name='permission-list'),
    path('permissions/<int:pk>/', PermissionDetailView.as_view(), name='permission-detail'),

    # Company (singleton)
    path('settings/company/', CompanyRetrieveUpdateView.as_view(), name='company'),

    # Audit Log (read-only)
    path('settings/audit/', AuditLogListView.as_view(), name='audit-log-list'),

    # SMTP Settings — unlimited named configs, one active at a time
    path('settings/smtp/',                    SMTPSettingsListCreateView.as_view(), name='smtp-list'),
    path('settings/smtp/<int:pk>/',           SMTPSettingsDetailView.as_view(),     name='smtp-detail'),
    path('settings/smtp/<int:pk>/activate/',  SMTPActivateView.as_view(),           name='smtp-activate'),
    path('settings/smtp/test/',               SMTPTestEmailView.as_view(),          name='smtp-test'),

    # Email Templates
    path('settings/email-templates/',                   EmailTemplateListCreateView.as_view(), name='email-template-list'),
    path('settings/email-templates/<int:pk>/',          EmailTemplateDetailView.as_view(),     name='email-template-detail'),
    path('settings/email-templates/<int:pk>/preview/',  EmailTemplatePreviewView.as_view(),    name='email-template-preview'),
]
