from django.db import models
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator

class Especie(models.Model):
    nombre = models.CharField(max_length=100)

    class Meta:
        db_table = 'especies'

    def __str__(self):
        return self.nombre

    #metodo propio 
    def total_ejemplares(self):
        """Calcula el número total de árboles de esta especie registrados en todos los inventarios."""
        return sum(item.cantidad for item in self.inventarios.all())

    # Método propio: Conteo global real en campo
    def conteo_global_por_estado(self, estado_buscado):
        """Calcula el total real de árboles de esta especie en un estado específico (SANO, DETERIORADO, etc.)."""
        from mantenimientos.models import ArbolPlantado
        return ArbolPlantado.objects.filter(
            inventario__especie=self,
            estado__iexact=estado_buscado
        ).count() 


class Inventario(models.Model):
    especie = models.ForeignKey(
        'inventarios.Especie',
        on_delete=models.CASCADE,
        db_column='especie_id',
        related_name='inventarios'
    )
    cantidad = models.IntegerField(validators=[MinValueValidator(1)])
    campania = models.ForeignKey(
        'campanias.Campania',
        on_delete=models.CASCADE,
        db_column='campania_id',
        related_name='inventarios'
    )
    img_url = models.URLField(max_length=250, blank=True, null=True)
    ubicacion = models.ForeignKey(
        'campanias.Ubicacion',
       on_delete=models.PROTECT,
        db_column='ubicacion_id',
        related_name='inventarios'
    )
    usuario = models.ForeignKey(
        'usuarios.Usuario',
        on_delete=models.CASCADE,
        db_column='usuario_id',
        related_name='inventarios_asignados'
    )
    ESTADOS_APROBACION = [
        ('PENDIENTE', 'Pendiente'),
        ('APROBADO', 'Aprobado'),
        ('RECHAZADO', 'Rechazado'),
    ]
    estado_aprobacion = models.CharField(
        max_length=20, choices=ESTADOS_APROBACION, default='PENDIENTE'
    )
    aprobado_por = models.ForeignKey(
        'usuarios.Usuario',
        on_delete=models.PROTECT,
        null=True, blank=True,
        db_column='aprobado_por',
        related_name='inventarios_aprobados'
    )
    fecha_aprobacion = models.DateTimeField(null=True, blank=True)
    class Meta:
        db_table = 'inventarios'

    def __str__(self):
        return f"Inventario #{self.id} - {self.especie.nombre}"

    """def save(self, *args, **kwargs):
        from mantenimientos.models import ArbolPlantado
        from django.utils import timezone

        # 1. Verificamos si el registro ya existe (si tiene PK es una actualización)
        if self.pk:
            # Obtenemos el registro original antes de los cambios en el formulario
            origen = Inventario.objects.get(pk=self.pk)
            diferencia = self.cantidad - origen.cantidad
        else:
            diferencia = None  # Es un registro nuevo

        # 2. Guardamos el inventario normalmente en la base de datos
        super().save(*args, **kwargs)

        # 3. S sincronizamos los árboles plantados según la diferencia
        if diferencia is None:
            # Si es nuevo, creamos todos los árboles iniciales como 'SANO'
            for _ in range(self.cantidad):
                ArbolPlantado.objects.create(
                    fecha=timezone.now().date(),
                    estado='SANO',
                    inventario=self
                )
        elif diferencia != 0:
            if diferencia > 0:
                # Si aumentó la cantidad, creamos los nuevos árboles
                for _ in range(diferencia):
                    ArbolPlantado.objects.create(
                        fecha=timezone.now().date(),
                        estado='SANO',
                        inventario=self
                    )
            elif diferencia < 0:
                # Si disminuyó la cantidad, eliminamos el exceso de árboles de forma segura.
                # Primero intentamos borrar los que están 'SANO'
                arboles_a_eliminar = self.arboles_plantados.filter(estado='SANO').order_by('-id')[:abs(diferencia)]
                
                # Si no hay suficientes sanos para cubrir la baja, eliminamos de cualquier estado
                if arboles_a_eliminar.count() < abs(diferencia):
                    arboles_a_eliminar = self.arboles_plantados.order_by('-id')[:abs(diferencia)]
                
                for arbol in arboles_a_eliminar:
                    arbol.delete()"""



    def save(self, *args, **kwargs):
        from mantenimientos.models import ArbolPlantado
        from django.utils import timezone

        if self.pk:
            origen = Inventario.objects.get(pk=self.pk)
            diferencia = self.cantidad - origen.cantidad
            
            # Si la cantidad disminuyó, debemos verificar si los árboles a eliminar tienen mantenimientos
            if diferencia < 0:
                abs_diferencia = abs(diferencia)
                
                # Buscamos los árboles que se intentarían eliminar (priorizando los 'SANO')
                arboles_a_eliminar = list(self.arboles_plantados.filter(estado='SANO').order_by('-id')[:abs_diferencia])
                if len(arboles_a_eliminar) < abs_diferencia:
                    # Si no bastan los sanos, completamos con el resto
                    ids_existentes = [a.id for a in arboles_a_eliminar]
                    adicionales = self.arboles_plantados.exclude(id__in=ids_existentes).order_by('-id')[:(abs_diferencia - len(arboles_a_eliminar))]
                    arboles_a_eliminar.extend(list(adicionales))
                
                # Validamos si alguno de los árboles a eliminar tiene mantenimientos registrados
                for arbol in arboles_a_eliminar:
                    if arbol.mantenimientos.exists(): # Asumiendo related_name='mantenimientos' en el modelo Mantenimiento
                        raise ValidationError(
                            "No se puede actualizar o disminuir la cantidad de árboles plantados porque tienen registros de mantenimiento asociados."
                        )
        else:
            diferencia = None

        # Guardamos el inventario normalmente si pasa la validación
        super().save(*args, **kwargs)

        # Sincronización de árboles (crear o eliminar de forma segura)
        if diferencia is None:
            for _ in range(self.cantidad):
                ArbolPlantado.objects.create(
                    fecha=timezone.now().date(),
                    estado='SANO',
                    inventario=self
                )
        elif diferencia != 0:
            if diferencia > 0:
                for _ in range(diferencia):
                    ArbolPlantado.objects.create(
                        fecha=timezone.now().date(),
                        estado='SANO',
                        inventario=self
                    )
            elif diferencia < 0:
                arboles_a_eliminar = self.arboles_plantados.filter(estado='SANO').order_by('-id')[:abs(diferencia)]
                if arboles_a_eliminar.count() < abs(diferencia):
                    arboles_a_eliminar = self.arboles_plantados.order_by('-id')[:abs(diferencia)]
                for arbol in arboles_a_eliminar:
                    arbol.delete()




      #al final se coloco toda la logica de sincronizacion en save
    def actualizar_cantidad(self, nueva_cantidad):
        """Actualiza la cantidad de árboles y sincroniza los registros individuales en arboles_plantados."""
        if nueva_cantidad >= 0:
            from mantenimientos.models import ArbolPlantado
            from django.utils import timezone

            # Calculamos la diferencia entre la cantidad actual y la nueva
            diferencia = nueva_cantidad - self.cantidad
            self.cantidad = nueva_cantidad
            self.save(update_fields=['cantidad']) # Guardamos solo el campo cantidad

            if diferencia > 0:
                # Si aumentó, creamos los nuevos árboles como 'SANO'
                for _ in range(diferencia):
                    ArbolPlantado.objects.create(
                        fecha=timezone.now().date(),
                        estado='SANO',
                        inventario=self
                    )
            elif diferencia < 0:
                # Si disminuyó, eliminamos el exceso de árboles de forma segura
                arboles_a_eliminar = self.arboles_plantados.filter(estado='SANO').order_by('-id')[:abs(diferencia)]
                if arboles_a_eliminar.count() < abs(diferencia):
                    arboles_a_eliminar = self.arboles_plantados.order_by('-id')[:abs(diferencia)]
                
                for arbol in arboles_a_eliminar:
                    arbol.delete()

            return True
        return False
    
     #metodo devuelve una cantidad de arboles con estado especifico de ese LOTE
    def conteo_por_estado(self, estado_buscado):
        return self.arboles_plantados.filter(estado__iexact=estado_buscado).count()
    
    #devuelve la cantidad de arboles sanos en ese lote
    def arboles_sanos(self):
        """Devuelve la cantidad de árboles sanos en este lote."""
        return self.conteo_por_estado('SANO')
    
     #devuelve la cantidad de arboles deteriorados en ese lote
    def arboles_deteriorados(self):
        """Devuelve la cantidad de árboles deteriorados en este lote."""
        return self.conteo_por_estado('DETERIORADO')

    def arboles_perdidos(self):
        return self.conteo_por_estado('PERDIDO')