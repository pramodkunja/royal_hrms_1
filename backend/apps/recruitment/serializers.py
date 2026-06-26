from rest_framework import serializers

from .models import Candidate, CandidateEmail, CandidateLog


class CandidateLogSerializer(serializers.ModelSerializer):
    class Meta:
        model  = CandidateLog
        fields = ['id', 'log_type', 'title', 'description', 'created_at']


class CandidateEmailSerializer(serializers.ModelSerializer):
    sent_by_name = serializers.SerializerMethodField()

    class Meta:
        model  = CandidateEmail
        fields = ['id', 'template_used', 'subject', 'to_email', 'status', 'sent_by_name', 'sent_at',
                  'candidate', 'candidate_name', 'candidate_position']

    def get_sent_by_name(self, obj):
        if obj.sent_by:
            return obj.sent_by.full_name or obj.sent_by.email
        return ''

    # Extra read-only fields that join candidate data for the email logs page
    candidate_name     = serializers.CharField(source='candidate.name',             read_only=True)
    candidate_position = serializers.CharField(source='candidate.position_applied', read_only=True)


class CandidateListSerializer(serializers.ModelSerializer):
    interviewer_name = serializers.SerializerMethodField()
    added_by_name    = serializers.SerializerMethodField()
    referral_by_name = serializers.SerializerMethodField()

    class Meta:
        model  = Candidate
        fields = [
            'id', 'name', 'email', 'phone', 'position_applied',
            'interview_date', 'interviewer', 'interviewer_name', 'interview_mode',
            'notes', 'status', 'referral_by', 'referral_by_name',
            'details_filled', 'hr_approved', 'portal_credentials_sent',
            'added_by_name', 'created_at', 'updated_at',
        ]

    def get_interviewer_name(self, obj):
        if obj.interviewer:
            return obj.interviewer.full_name or obj.interviewer.email
        return ''

    def get_added_by_name(self, obj):
        if obj.added_by:
            return obj.added_by.full_name or obj.added_by.email
        return ''

    def get_referral_by_name(self, obj):
        if obj.referral_by:
            return obj.referral_by.full_name or obj.referral_by.email
        return ''


class CandidateDetailSerializer(CandidateListSerializer):
    logs = CandidateLogSerializer(many=True, read_only=True)

    class Meta(CandidateListSerializer.Meta):
        fields = CandidateListSerializer.Meta.fields + ['logs']


class CandidateCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Candidate
        fields = [
            'name', 'email', 'phone', 'position_applied',
            'interview_date', 'interviewer', 'interview_mode', 'notes',
        ]
