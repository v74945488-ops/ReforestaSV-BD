from django.db import models


# ==========================================
# MODELO PRINCIPAL ('usuarios')
# Django NO controla esta tabla: la crea el script SQL.
# El login vive en auth_user y se enlaza por correo.
# ==========================================

class Usuario(models.Model):
    class Rol(models.TextChoices):
        ADMIN = 'ADMIN', 'Administrador'
        VOLUNTARIO = 'VOLUNTARIO', 'Voluntario'
        RESPONSABLE = 'RESPONSABLE', 'Responsable'

    nombre = models.CharField(max_length=200)
    telefono = models.CharField(max_length=8, blank=True, null=True)
    correo = models.EmailField(max_length=250, blank=True, null=True)
    institucion = models.CharField(max_length=200, blank=True, null=True)
    localidad = models.CharField(max_length=200, blank=True, null=True)
    rol = models.CharField(max_length=20, choices=Rol.choices, default=Rol.VOLUNTARIO)
    activo = models.BooleanField(default=True)

    @property
    def es_admin(self):
        return self.rol == self.Rol.ADMIN

    @property
    def es_responsable(self):
        return self.rol == self.Rol.RESPONSABLE

    @property
    def es_voluntario(self):
        return self.rol == self.Rol.VOLUNTARIO

    class Meta:
        db_table = 'usuarios'
        managed = False

    def __str__(self):
        return f"{self.nombre} ({self.rol})"


# ==========================================
# MANAGERS
# ==========================================

class ResponsableManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(rol=Usuario.Rol.RESPONSABLE)


class VoluntarioManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(rol=Usuario.Rol.VOLUNTARIO)


class AdminManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(rol=Usuario.Rol.ADMIN)


# ==========================================
# MODELOS PROXY
# ==========================================

class Admin(Usuario):
    objects = AdminManager()

    class Meta:
        proxy = True

    def save(self, *args, **kwargs):
        self.rol = Usuario.Rol.ADMIN
        super().save(*args, **kwargs)


class Voluntario(Usuario):
    objects = VoluntarioManager()

    class Meta:
        proxy = True

    def save(self, *args, **kwargs):
        self.rol = Usuario.Rol.VOLUNTARIO
        super().save(*args, **kwargs)


class Responsable(Usuario):
    objects = ResponsableManager()

    class Meta:
        proxy = True

    def save(self, *args, **kwargs):
        self.rol = Usuario.Rol.RESPONSABLE
        super().save(*args, **kwargs)