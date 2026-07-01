import 'package:flutter/material.dart';

// Icon per backend leave type code — matches the reference web frontend's
// Tabler icon choices (ti-beach, ti-calendar-check, ti-stethoscope,
// ti-coin-off, ti-heart, ti-baby-carriage) with their closest Material icons.
IconData leaveTypeIconForCode(String code) => switch (code.toLowerCase()) {
      'casual'    => Icons.beach_access_outlined,
      'earned'    => Icons.event_available_outlined,
      'sick'      => Icons.medical_services_outlined,
      'lwp'       => Icons.money_off_outlined,
      'maternity' => Icons.favorite_outline,
      'paternity' => Icons.child_friendly_outlined,
      _           => Icons.beach_access_outlined,
    };
