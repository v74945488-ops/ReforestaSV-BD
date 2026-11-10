from django.db import models
from django.conf import settings
from django.utils import timezone
from django.core.validators import MinValueValidator

class Ubicacion(models.Model):
    zona = models.CharField(max_length=150)
    ubicacion = models.CharField(max_length=250)

    class Meta:
        db_table = "ubicaciones"

    def __str__(self):
        return f"{self.zona} - {self.ubicacion}"

    
    #metodo propio, actualiza los datos de ubicacion
    def actualizar_ubicacion(self, nueva_zona=None, nueva_direccion=None):
        # Modifica la zona o dirección si se le pasan nuevos valores y guarda
        if nueva_zona:
            self.zona = nueva_zona
        if nueva_direccion:
            self.ubicacion = nueva_direccion
        self.save()


class Campania(models.Model):
    titulo = models.CharField(max_length=150)
    descripcion = models.CharField(max_length=200, blank=True, null=True)
    #la variable debe de tener relacion con db_colum
    responsable = models.ForeignKey(
        'usuarios.Usuario',
        on_delete=models.CASCADE,
        db_column='responsable_id',
        related_name='campanias'
    )
        
    
    meta_arboles = models.IntegerField(validators=[MinValueValidator(1)])
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField(blank=True, null=True)

    class Meta:
        db_table = 'campanias'

    def __str__(self):
        return self.titulo

   #Metodos propios 

    def obtener_participantes(self):
        """
        Obtiene la lista de todos los Usuarios (voluntarios o responsables)
        que tienen lotes de inventario asignados dentro de esta campaña.
        """
        from usuarios.models import Usuario

        # IDs únicos de la columna usuario_id en la tabla inventarios
        ids_usuarios = self.inventarios.values_list('usuario_id', flat=True).distinct()
        return Usuario.objects.filter(id__in=ids_usuarios)

    
    def duracion_dias(self):
        """Duración total de la campaña en días (None si aún no tiene fecha de fin)."""
        if not self.fecha_fin:
            return None
        diferencia = (self.fecha_fin - self.fecha_inicio).days
        return diferencia + 1 if diferencia > 0 else 1

    @property
    def esta_activa(self):
        """Activa si ya empezó y no ha terminado (o no tiene fecha de fin)."""
        hoy = timezone.localdate()
        return self.fecha_inicio <= hoy and (self.fecha_fin is None or hoy <= self.fecha_fin)