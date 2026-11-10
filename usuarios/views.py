# usuarios/views.py
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.decorators import login_required
from .forms import UsuarioForm, UsuarioEditarForm
from .models import Usuario
from .decorators import rol_requerido

User = get_user_model()


@login_required
def crear_usuario(request):
    if request.method == 'POST':
        form = UsuarioForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Usuario creado correctamente!')
            return redirect('usuarios:usuarios')
    else:
        form = UsuarioForm()

    return render(request, 'usuarios/usuario_form.html', {
        'form': form,
        'titulo': 'Nuevo Usuario'
    })


@rol_requerido('ADMIN', 'RESPONSABLE')
def usuarios_list(request):
    tipo_rol = request.GET.get('tipo', '')

    usuarios = Usuario.objects.all()
    if tipo_rol:
        usuarios = usuarios.filter(rol=tipo_rol)

    return render(request, 'usuarios/usuarios.html', {
        'usuarios': usuarios,
    })


# Vista de Edición
@rol_requerido('ADMIN', 'RESPONSABLE')
@login_required
def editar_usuario(request, pk):
    usuario = get_object_or_404(Usuario, pk=pk)
    if request.method == 'POST':
        form = UsuarioEditarForm(request.POST, instance=usuario)
        if form.is_valid():
            form.save()
            messages.success(request, 'Usuario actualizado correctamente!')
            return redirect('usuarios:usuarios')
    else:
        form = UsuarioEditarForm(instance=usuario)

    return render(request, 'usuarios/usuario_form.html', {
        'form': form,
        'usuario': usuario
    })


# Vista de Eliminación
@login_required
@rol_requerido('ADMIN')
def eliminar_usuario(request, pk):
    usuario = get_object_or_404(Usuario, pk=pk)
    if request.method == 'POST':
        if usuario.correo:
            User.objects.filter(email__iexact=usuario.correo).delete()
        usuario.delete()
        messages.success(request, 'Usuario eliminado correctamente!')
        return redirect('usuarios:usuarios')

    if request.user.is_authenticated:
        print(f"Usuario actual: {request.user.nombre}")
    return render(request, 'usuarios/usuario_confirm_delete.html', {'usuario': usuario})