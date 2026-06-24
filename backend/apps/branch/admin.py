from django.contrib import admin

from apps.branch.models import Branch, City, State


@admin.register(State)
class StateAdmin(admin.ModelAdmin):
    list_display = ['name', 'code', 'is_active']
    list_filter = ['is_active']
    search_fields = ['name', 'code']


@admin.register(City)
class CityAdmin(admin.ModelAdmin):
    list_display = ['name', 'state', 'is_active']
    list_filter = ['is_active', 'state']
    search_fields = ['name']
    autocomplete_fields = ['state']


@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display = [
        'branch_code', 'branch_name', 'city', 'state',
        'status', 'is_headquarter', 'employees_count',
    ]
    list_filter = ['status', 'is_headquarter', 'state']
    search_fields = ['branch_code', 'branch_name']
    autocomplete_fields = ['state', 'city']
