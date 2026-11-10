from django.db import models
from django.conf import settings
from django.utils import timezone

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
        
    
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField()

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
        """Calcula la duración total de la campaña en días."""
        diferencia = (self.fecha_fin - self.fecha_inicio).days
        
        # Si inicia y termina el mismo día, cuenta como 1 día. De lo contrario, sumamos 1 para incluir el día de inicio.
        if diferencia == 0:
            return 1
        return diferencia + 1 if diferencia > 0 else 1