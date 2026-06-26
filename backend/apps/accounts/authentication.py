from rest_framework_simplejwt.authentication import JWTAuthentication as _JWTAuthentication


class CookieJWTAuthentication(_JWTAuthentication):
    """Reads the JWT access token from the httpOnly 'royal_access_token' cookie."""

    def authenticate(self, request):
        raw_token = request.COOKIES.get('royal_access_token')
        if not raw_token:
            return None
        try:
            validated = self.get_validated_token(raw_token.encode())
            return self.get_user(validated), validated
        except Exception:
            return None
