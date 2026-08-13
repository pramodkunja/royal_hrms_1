// Mirrors frontend/lib/faceApi/consentText.ts exactly — same wording, same
// separation between the self-service notice (employee ticks it themselves)
// and the HR-witnessed one (HR confirms the employee consented in person).
// The backend stamps its own FACE_CONSENT_TEXT_VERSION server-side when the
// capture is submitted; mobile only ever sends the `consent_acknowledged`
// boolean, never a version string, same as web.

const String kFaceConsentNoticeEmployee =
    'I understand my facial data will be captured and converted into a numeric '
    'face signature (not a photo or video) to verify my identity for clock-in '
    'and clock-out. This signature is stored securely, used only for attendance '
    'verification, and is never shared outside this purpose. I can ask HR to '
    'update it at any time, and it will be deleted when my employment ends.';

const String kFaceConsentNoticeHr =
    'I confirm the employee has been informed that their facial data will be '
    'captured and converted into a numeric face signature (not a photo or '
    'video) to verify their identity for clock-in and clock-out, that it is '
    'stored securely and used only for that purpose, and that they have '
    'verbally consented to this capture before I proceed.';
