from django.contrib import admin

from .models import Admin, Responsable, Usuario, Voluntario


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ('nombre', 'rol', 'correo', 'telefono', 'activo')
    list_filter = ('rol', 'activo')
    search_fields = ('nombre', 'correo')


admin.site.register(Admin)
admin.site.register(Voluntario)
admin.site.register(Responsable)
