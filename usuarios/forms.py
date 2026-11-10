from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import transaction

from .models import Usuario

User = get_user_model()


class BaseUsuarioForm(forms.ModelForm):
    """
    Los datos del proyecto van a la tabla usuarios y el login a auth_user.
    Se enlazan por el correo.
    """

    username = forms.CharField(
        max_length=150,
        widget=forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ej. juanperez'}),
    )
    email = forms.EmailField(
        max_length=250,
        widget=forms.EmailInput(attrs={'class': 'form-control'}),
    )

    class Meta:
        model = Usuario
        fields = ['nombre', 'telefono', 'rol', 'institucion', 'localidad']
        widgets = {
            'nombre': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ej. Juan Pérez'}),
            'telefono': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ej. 77001122', 'maxlength': 8}),
            'rol': forms.Select(attrs={'class': 'form-select'}),
            'institucion': forms.TextInput(attrs={'class': 'form-control'}),
            'localidad': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Reubicación #1'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.cuenta = None  # cuenta de login (auth_user) enlazada, si existe
        self.fields['institucion'].required = False
        self.fields['localidad'].required = False

    def clean_username(self):
        username = self.cleaned_data['username'].strip()
        cuentas = User.objects.filter(username__iexact=username)
        if self.cuenta:
            cuentas = cuentas.exclude(pk=self.cuenta.pk)
        if cuentas.exists():
            raise ValidationError('Ese nombre de usuario ya existe.')
        return username

    def clean_email(self):
        email = self.cleaned_data['email'].strip().lower()
        usuarios = Usuario.objects.filter(correo__iexact=email)
        cuentas = User.objects.filter(email__iexact=email)
        if self.instance.pk:
            usuarios = usuarios.exclude(pk=self.instance.pk)
        if self.cuenta:
            cuentas = cuentas.exclude(pk=self.cuenta.pk)
        if usuarios.exists() or cuentas.exists():
            raise ValidationError('Ese correo ya está registrado.')
        return email

    def clean_telefono(self):
        telefono = self.cleaned_data.get('telefono')
        if telefono and (len(telefono) != 8 or not telefono.isdigit()):
            raise ValidationError('El teléfono debe tener exactamente 8 dígitos.')
        return telefono or None

    def clean(self):
        cleaned = super().clean()
        rol = cleaned.get('rol')
        cleaned['institucion'] = cleaned.get('institucion') or None
        cleaned['localidad'] = cleaned.get('localidad') or None
        # Misma regla que la plantilla: el administrador no lleva ninguno,
        # el voluntario no lleva institución y el responsable no lleva localidad
        if rol == Usuario.Rol.ADMIN:
            cleaned['institucion'] = None
            cleaned['localidad'] = None
        elif rol == Usuario.Rol.VOLUNTARIO:
            cleaned['institucion'] = None
        elif rol == Usuario.Rol.RESPONSABLE:
            cleaned['localidad'] = None
        return cleaned


class UsuarioForm(BaseUsuarioForm):
    password1 = forms.CharField(
        strip=False,
        widget=forms.PasswordInput(attrs={'class': 'form-control', 'placeholder': 'Contraseña'}),
    )
    password2 = forms.CharField(
        strip=False,
        widget=forms.PasswordInput(attrs={'class': 'form-control', 'placeholder': 'Repita la contraseña'}),
    )

    def clean_password2(self):
        p1 = self.cleaned_data.get('password1')
        p2 = self.cleaned_data.get('password2')
        if p1 and p2 and p1 != p2:
            raise ValidationError('Las contraseñas no coinciden.')
        if p2:
            validate_password(p2, user=User(
                username=self.cleaned_data.get('username', ''),
                email=self.cleaned_data.get('email', ''),
            ))
        return p2

    @transaction.atomic
    def save(self, commit=True):
        usuario = super().save(commit=False)
        usuario.correo = self.cleaned_data['email']
        usuario.activo = True
        usuario.save()
        User.objects.create_user(
            username=self.cleaned_data['username'],
            email=usuario.correo,
            password=self.cleaned_data['password1'],
        )
        return usuario


class UsuarioEditarForm(BaseUsuarioForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        correo = self.instance.correo if self.instance.pk else None
        if correo:
            self.cuenta = User.objects.filter(email__iexact=correo).first()
        self.fields['email'].initial = correo
        if self.cuenta:
            self.fields['username'].initial = self.cuenta.username
        else:
            # Usuarios sin cuenta de login (p. ej. los de prueba)
            self.fields['username'].required = False

    @transaction.atomic
    def save(self, commit=True):
        usuario = super().save(commit=False)
        usuario.correo = self.cleaned_data['email']
        usuario.save()
        if self.cuenta:
            self.cuenta.email = usuario.correo
            self.cuenta.username = self.cleaned_data['username']
            self.cuenta.save()
        return usuario
