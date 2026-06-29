from django.urls import path

from .views import ExpenseListCreateView, ExpenseStatsView

urlpatterns = [
    path('expenses/',       ExpenseListCreateView.as_view(), name='expense-list-create'),
    path('expenses/stats/', ExpenseStatsView.as_view(),      name='expense-stats'),
]
