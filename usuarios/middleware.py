from .models import Usuario


class UsuarioMiddleware:
    """Enlaza el login de Django (auth_user) con la tabla usuarios por correo."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = request.user
        if user.is_authenticated:
            usuario = None
            if user.email:
                usuario = Usuario.objects.filter(
                    correo__iexact=user.email, activo=True
                ).first()
            user.usuario = usuario
            user.rol = usuario.rol if usuario else None
            user.nombre = usuario.nombre if usuario else user.get_username()
            user.es_admin = bool(usuario and usuario.es_admin)
            user.es_responsable = bool(usuario and usuario.es_responsable)
            user.es_voluntario = bool(usuario and usuario.es_voluntario)
        return self.get_response(request)