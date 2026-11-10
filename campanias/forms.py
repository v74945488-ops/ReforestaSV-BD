import re

from django import forms
from django.core.exceptions import ValidationError

from usuarios.models import Usuario
from .models import Campania, Ubicacion


class CampaniaForm(forms.ModelForm):
    class Meta:
        model = Campania
        fields = ['titulo', 'descripcion', 'responsable', 'meta_arboles', 'fecha_inicio', 'fecha_fin']
        labels = {
            'meta_arboles': 'Meta de árboles',
            'fecha_fin': 'Fecha de fin (opcional)',
        }
        widgets = {
            'titulo': forms.TextInput(attrs={
                'class': 'form-control',
                'maxlength': '150'
            }),
            'descripcion': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'maxlength': '200'
            }),
            'responsable': forms.Select(attrs={'class': 'form-select'}),
            'meta_arboles': forms.NumberInput(attrs={
                'class': 'form-control',
                'placeholder': 'Ej. 500',
                'min': 1
            }),
            'fecha_inicio': forms.DateInput(attrs={'class': 'form-control', 'type': 'date'}),
            'fecha_fin': forms.DateInput(attrs={'class': 'form-control', 'type': 'date'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # La base solo acepta como responsable a un usuario RESPONSABLE y activo
        self.fields['responsable'].queryset = Usuario.objects.filter(
            rol=Usuario.Rol.RESPONSABLE,
            activo=True,
        ).order_by('nombre')
        self.fields['responsable'].empty_label = "Seleccione un responsable..."

    def clean(self):
        cleaned_data = super().clean()
        fecha_inicio = cleaned_data.get('fecha_inicio')
        fecha_fin = cleaned_data.get('fecha_fin')

        if fecha_inicio and fecha_fin and fecha_fin < fecha_inicio:
            self.add_error('fecha_fin', 'La fecha final no puede ser menor a la fecha de inicio.')

        return cleaned_data


class UbicacionForm(forms.ModelForm):
    class Meta:
        model = Ubicacion
        fields = ['zona', 'ubicacion']
        labels = {
            'zona': 'Zona geográfica',
            'ubicacion': 'Dirección o descripción de ubicación',
        }
        widgets = {
            'zona': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ej. Zona A o Zona 1'}),
            'ubicacion': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ej. Apopa'}),
        }

    def clean_zona(self):
        zona = self.cleaned_data.get('zona', '').strip()

        if len(zona) < 2:
            raise ValidationError("La zona debe tener al menos 2 caracteres.")

        # Debe contener al menos una letra (evita que sean solo números o símbolos)
        if not any(c.isalpha() for c in zona):
            raise ValidationError("La zona debe contener al menos una letra.")

        # Evitar spam de letras repetidas (ej. "jjjjjj")
        if re.search(r'(.)\1{4,}', zona):
            raise ValidationError("La zona contiene demasiados caracteres repetidos consecutivos.")

        # Permite letras, números, espacios y guiones
        if not re.match(r'^[a-zA-ZÁÉÍÓÚáéíóúÑñ0-9\s-]+$', zona):
            raise ValidationError("La zona no debe contener caracteres especiales.")

        return zona

    def clean_ubicacion(self):
        ubicacion = self.cleaned_data.get('ubicacion', '').strip()

        if len(ubicacion) < 3:
            raise ValidationError("La ubicación debe tener al menos 3 caracteres.")

        if re.search(r'(.)\1{4,}', ubicacion):
            raise ValidationError("La ubicación contiene demasiados caracteres repetidos consecutivos.")

        if not re.match(r'^[a-zA-ZÁÉÍÓÚáéíóúÑñ0-9\s,\.-]+$', ubicacion):
            raise ValidationError("La ubicación contiene caracteres especiales no permitidos.")

        return ubicacion

    def clean(self):
        cleaned_data = super().clean()
        zona = cleaned_data.get('zona')
        ubicacion = cleaned_data.get('ubicacion')

        # Duplicados por la combinación exacta de zona + ubicación (sin distinguir mayúsculas)
        if zona and ubicacion:
            query = Ubicacion.objects.filter(zona__iexact=zona, ubicacion__iexact=ubicacion)

            # Al editar, se excluye el registro actual para que no choque consigo mismo
            if self.instance and self.instance.pk:
                query = query.exclude(pk=self.instance.pk)

            if query.exists():
                self.add_error('zona', "Ya existe un registro con esta misma combinación de zona y ubicación.")

        return cleaned_data
