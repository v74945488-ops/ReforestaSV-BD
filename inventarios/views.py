from django.shortcuts import render, redirect
from django.contrib import messages
from django.shortcuts import render, redirect, get_object_or_404

from usuarios.decorators import rol_requerido
from .models import Inventario
from .models import Especie
from .forms import InventarioForm
from campanias.models import Campania
from django.core.exceptions import ValidationError

# Create your views here.
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from .models import Especie
from .forms import EspecieForm

# 1. Listar especies
def especie_list(request):
    especies = Especie.objects.all()
    return render(request, 'especies/especie_list.html', {'especies': especies})

# 2. Crear nueva especie
@rol_requerido('ADMIN','RESPONSABLE')
def especie_crear(request):
    if request.method == 'POST':
        form = EspecieForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Especie guardada correctamente!')
            return redirect('inventarios:especie_list')
    else:
        form = EspecieForm()
    return render(request, 'especies/especie_form.html', {'form': form, 'titulo': 'Nueva Especie'})

# 3. Editar especie
@rol_requerido('ADMIN')
def especie_editar(request, pk):
    especie = get_object_or_404(Especie, pk=pk)
    if request.method == 'POST':
        form = EspecieForm(request.POST, instance=especie)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Especie actualizada correctamente!')
            return redirect('inventarios:especie_list')
    else:
        form = EspecieForm(instance=especie)
    return render(request, 'especies/especie_form.html', {'form': form, 'titulo': 'Editar Especie'})

# 4. Eliminar especie
@rol_requerido('ADMIN')
def especie_eliminar(request, pk):
    especie = get_object_or_404(Especie, pk=pk)
    
    if especie.inventarios.exists():
        messages.error(
            request, 
            f"No se puede eliminar la especie '{especie.nombre}' porque está asignada a uno o más inventarios."
        )
        return redirect('inventarios:especie_list')
        
    if request.method == 'POST':
        especie.delete()
        messages.success(request, 'Especie eliminada correctamente.')
        return redirect('inventarios:especie_list')
        
    return render(request, 'especies/especie_confirm_delete.html', {'especie': especie})

#funciones de inventario
@rol_requerido('ADMIN', 'RESPONSABLE','VOLUNTARIO')
def inventario_list(view_request):
    """Vista para listar los inventarios existentes con sus relaciones."""
    inventarios = Inventario.objects.all()
    campanias = Campania.objects.all()  # Obtenemos todas las campañas para llenar el select
    especies = Especie.objects.all()
    campania_id = view_request.GET.get('campania')
    especie_id = view_request.GET.get('especie')

    #filtrar por campaña por si se seleccionó alguna
    if campania_id:
        # Filtramos los inventarios que coincidan con la campaña seleccionada
        inventarios = inventarios.filter(campania_id=campania_id)

    #Filtrar por especie si se seleccionó
    if especie_id:
        inventarios = inventarios.filter(especie_id=especie_id)
        
    context = {
        'inventarios': inventarios,
        'campanias': campanias,
        'especies': especies,
        'campania_seleccionada': campania_id,  # Para mantener la opción seleccionada en el select
        'especie_seleccionada': especie_id,
    }
    return render(view_request, 'inventarios/inventario_list.html', context)
@rol_requerido('ADMIN', 'RESPONSABLE','VOLUNTARIO')
def inventario_create(view_request):
    if view_request.method == 'POST':
       
        form = InventarioForm(view_request.POST, view_request.FILES)
        if form.is_valid():
            form.save()
            messages.success(view_request, "¡Inventario registrado exitosamente!")
            return redirect('inventarios:inventario_list')
    else:
        form = InventarioForm()
    
    return render(view_request, 'inventarios/inventario_form.html', {'form': form})

"""def inventario_update(request, pk):
    inventario = get_object_or_404(Inventario, pk=pk)
    
    if request.method == 'POST':
        form = InventarioForm(request.POST, request.FILES, instance=inventario)
        if form.is_valid():
            # El formulario se encargará de guardar y actualizar los árboles limpiamente
            form.save()
            messages.success(request, "¡Inventario actualizado correctamente!")
            return redirect('inventarios:inventario_list')
    else:
        form = InventarioForm(instance=inventario)
    
    return render(request, 'inventarios/inventario_form.html', {'form': form, 'editando': True})"""
@rol_requerido('ADMIN', 'RESPONSABLE')
def inventario_update(request, pk):
    inventario = get_object_or_404(Inventario, pk=pk)
    
    if request.method == 'POST':
        form = InventarioForm(request.POST, request.FILES, instance=inventario)
        if form.is_valid():
            try:
                # Intentamos guardar (esto disparará la validación del save del modelo)
                form.save()
                messages.success(request, "¡Inventario actualizado correctamente!")
                return redirect('inventarios:inventario_list')
            except ValidationError as e:
                # Si el modelo lanza el error por los mantenimientos, lo capturamos aquí
                mensaje_error = e.messages[0] if hasattr(e, 'messages') else str(e)
                messages.error(request, f"Advertencia: {mensaje_error}")
    else:
        form = InventarioForm(instance=inventario)
    
    return render(request, 'inventarios/inventario_form.html', {'form': form, 'editando': True})


    
  
@rol_requerido('ADMIN')
def inventario_delete(request, pk):
    inventario = get_object_or_404(Inventario, pk=pk)
    if request.method == 'POST':
        inventario.delete() # Método nativo de Django para borrar de la base de datos
        messages.success(request, "¡El registro de inventario ha sido eliminado!")
        return redirect('inventarios:inventario_list')
    
    return render(request, 'inventarios/inventario_confirm_delete.html', {'inventario': inventario})
