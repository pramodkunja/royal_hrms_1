/// The medical proof attached to a "WFH for medical reasons" request.
///
/// Backend contract (WorkFromHomeRequestCreateSerializer, apps/hrms/
/// serializers.py): `supporting_document` must be a PDF, JPEG or PNG — the
/// server checks the uploaded part's content type — and at most 5 MB, and
/// `is_medical` without a document is refused. Web: frontend/lib/wfhReport.ts
/// wfhMedicalProofError.
class WfhMedicalProof {
  final String path;
  final String filename;
  final int sizeBytes;

  const WfhMedicalProof(
      {required this.path, required this.filename, required this.sizeBytes});
}

const kWfhProofMaxBytes = 5 * 1024 * 1024;

/// Extension → content type sent for the file part. Only these are allowed.
const kWfhProofMimeTypes = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
};

const kWfhProofExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

const kWfhProofRequired = 'Attach a medical proof, report or prescription.';
const kWfhProofWrongType = 'Medical proof must be a PDF, JPG or PNG file.';
const kWfhProofTooLarge = 'Medical proof must be 5 MB or smaller.';

/// The content type for [filename], or null when its extension isn't allowed.
String? wfhProofMimeType(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return null;
  return kWfhProofMimeTypes[filename.substring(dot + 1).toLowerCase()];
}

/// Web's wfhMedicalProofError: null when the request may be sent.
String? wfhMedicalProofError(
    {required bool isMedical, WfhMedicalProof? proof}) {
  if (!isMedical) return null;
  if (proof == null) return kWfhProofRequired;
  if (wfhProofMimeType(proof.filename) == null) return kWfhProofWrongType;
  if (proof.sizeBytes > kWfhProofMaxBytes) return kWfhProofTooLarge;
  return null;
}
