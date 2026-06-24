from django.db import transaction
from rest_framework import serializers

from apps.branch.models import Branch, City, State
from apps.branch.utils import generate_branch_code, get_city_prefix


class StateSerializer(serializers.ModelSerializer):
    class Meta:
        model = State
        fields = ['id', 'name', 'code', 'is_active']


class CitySerializer(serializers.ModelSerializer):
    state_name = serializers.CharField(source='state.name', read_only=True)

    class Meta:
        model = City
        fields = ['id', 'name', 'state', 'state_name', 'is_active']


class BranchSerializer(serializers.ModelSerializer):
    state_name = serializers.CharField(source='state.name', read_only=True)
    city_name = serializers.CharField(source='city.name', read_only=True)

    class Meta:
        model = Branch
        fields = [
            'id', 'branch_code', 'branch_name', 'address',
            'state', 'state_name', 'city', 'city_name',
            'employees_count', 'status', 'is_headquarter',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['branch_code', 'created_at', 'updated_at']

    def validate(self, data):
        city = data.get('city') or (self.instance.city if self.instance else None)
        state = data.get('state') or (self.instance.state if self.instance else None)
        if city and state and city.state_id != state.pk:
            raise serializers.ValidationError(
                'Selected city does not belong to the selected state.'
            )
        return data

    def create(self, validated_data):
        city = validated_data['city']
        prefix = get_city_prefix(city.name)
        with transaction.atomic():
            existing = set(
                Branch.objects
                .select_for_update()
                .filter(branch_code__startswith=prefix)
                .values_list('branch_code', flat=True)
            )
            if prefix not in existing:
                branch_code = prefix
            else:
                max_num = max(
                    (
                        int(code[len(prefix) + 1:])
                        for code in existing
                        if code.startswith(prefix + '-') and code[len(prefix) + 1:].isdigit()
                    ),
                    default=0,
                )
                branch_code = f"{prefix}-{max_num + 1:02d}"
            return Branch.objects.create(branch_code=branch_code, **validated_data)

    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance
