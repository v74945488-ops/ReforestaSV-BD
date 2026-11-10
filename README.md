## Descripción del proyecto: 
Consiste en desarrollar una aplicación web que permita llevar un registro de los arboles 
plantados durante campañas de reforestación en la comunidad, facilitando así la organización y el seguimiento de la campaña.

**Integrantes:**
- Fátima Andrea Ochoa Amaya
- Gabriela Nicole Aquino Solís 
- Diego Omar Landaverde Ayala
- Katherine Yamileth Mancía Hernández 
- Saira Stephanie Melgar Abrego
- Víctor Javier Vásquez Ceron

**Descripción de la problematica**
El Cerro de Nejapa y sus zonas aledañas enfrentan problemas de degradación ambiental relacionados con la pérdida de cobertura vegetal, la erosión del suelo y la presión sobre los recursos naturales. La pérdida de vegetación puede contribuir a una mayor vulnerabilidad del terreno ante procesos de erosión, deslizamientos e inundaciones, además de afectar la biodiversidad y la capacidad del suelo para retener e infiltrar agua, ante esta situación las campañas de reforestación se suman como una medida protectora que puede ayudar ante la problemática, sin embargo, la falta de un registro organizado dificulta conocer la cantidad de árboles plantados, su especie, ubicación, responsable de su cuidado y estado actual, lo que puede limitar el seguimiento de las actividades de mantenimiento y la identificación de árboles dañados o perdidos. 

**Beneficiaros**
Comité Ambiental Comunitario del Cerro de Nejapa, comunidades aledañas y instituciones como ADESCO, ya que las campañas de reforestación son mayormente coordinados por estas organizaciones. 


## Requesitos funcionales.
**Requisitos:**
- El sistema permitirá registrar diferentes tipos de árboles.
- Llevar un control de la cantidad de árboles con la que se cuenta de cada tipo.
- Permitirá consultar el estado de los árboles plantados.
- El sistema permitirá eliminar registros con una alerta de confirmación.
- Se obtendrá un resumen  de los estados, cantidades y mantenimiento de los árboles
- El sistema permitirá filtrar árboles por tipo.
- En caso de deterioro o que el árbol se seque, se podrá actualizar el estado de dichos árboles.
- El sistema permitirá editar campos de los registros, como pueden ser cantidades de cada tipo de árbol.

## Requesitos no funcionales.
**Requesitos:**
- El sistema deberá ser responsivo, adaptarse a diferentes pantallas como teléfonos, tablets y computadoras.
- La interfaz contará únicamente con los elementos necesarios para su funcionamiento, manteniendo una estética simple y que resulte sencilla de manejar.
- El sistema contará con una interfaz que resuma la información más importante.
- Los formularios para el registro de la información estarán validados, para asegurar que la información registrada sea lo más correcta posible.
- El sistema deberá utilizar una base de datos SQL Server.
- La aplicación deberá desarrollarse con Django.
- La información relacionada con los usuarios será protegida limitando el acceso a esos datos.


## Clases del Sistema de Reforestación

1. CampaniaReforestacion

Responsabilidad: Gestionar las campañas de siembra y coordinar los lotes de árboles asignados.

* Atributos: id, nombre, titulo, fecha_inicio, fecha_fin.
* Métodos: registrarCampaña(), actualizarDatos(), consultarInventario().
* Relaciones:
    * Se asocia con Usuario, quien gestiona la campaña.
    * Tiene una composición con Inventario, cuyos lotes pertenecen a una campaña.

2. Inventario

Responsabilidad: Controlar los lotes de árboles, su cantidad, estado y ubicación.

* Atributos: id, cantidad, estado, img_url.
* Métodos: registrarGrupo(), actualizarCantidad(), actualizarEstado(), consultarInventario().
* Relaciones:
    * Pertenece a una CampaniaReforestacion.
    * Se asocia con un Arbol y una Ubicacion.
    * Tiene una composición con Mantenimiento, que registra los cuidados del lote.

3. Arbol

Responsabilidad: Mantener el catálogo de árboles disponibles para la siembra.

* Atributos: id, nombre.
* Métodos: registrarArbol(), actualizarDatos().
* Relaciones:
    * Se asocia con una Especie.
    * Puede estar relacionado con varios registros de Inventario.

4. Mantenimiento

Responsabilidad: Registrar las actividades de cuidado de los lotes de árboles, como riego e inspecciones.

* Atributos: id, fecha, descripcion.
* Métodos: registrarMantenimiento(), consultarMantenimiento().
* Relaciones:
    * Pertenece a un único registro de Inventario.

5. Ubicacion

Responsabilidad: Administrar las zonas y ubicaciones físicas donde se encuentran los lotes de árboles.

* Atributos: id, zona, ubicacion.
* Métodos: registrarUbicacion(), actualizarUbicacion().
* Relaciones:
    * Puede estar asociada con varios registros de Inventario


## Requisitos:
-Python instalado
-Git instalado

## Instrucciones básicas para instalar y ejecutar la aplicación:

1.Clonar el repositorio

2.Entrar a la carpeta del proyecto

3.Crear un entorno virtual:
python -m venv .venv

4.Activar el entorno virtual
.venv\Scripts\activate

5.Instalar las dependencias
pip install -r requeriments.txt

## Cómo ejecutar el proyecto

Requisitos: Python 3.12 o superior, SQL Server con SSMS y ODBC Driver 17 for SQL Server.

1. Clonar el repositorio y entrar a la carpeta del proyecto.
2. Crear la base de datos: abrir `docs/ReforestaSVDB.sql` en SSMS y ejecutarlo completo **una sola vez**.
3. Crear el entorno virtual e instalar dependencias:
   ```
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```
4. Copiar `.env.example` como `.env` y poner el nombre de su servidor en `DB_HOST`
   (se ve en SSMS al conectarse, por ejemplo `localhost` o `DESKTOP-XXXX\SQLEXPRESS`).
5. Preparar las migraciones (las tablas del proyecto ya las crea el script SQL):
   ```
   python manage.py migrate auth
   python manage.py migrate admin
   python manage.py migrate sessions
   python manage.py migrate --fake
   ```
6. Crear su usuario de acceso, usando el correo `admin@reforestasv.org`:
   ```
   python manage.py createsuperuser
   ```
7. Iniciar el servidor: `python manage.py runserver`

Nota: la conexión usa autenticación de Windows. Quien entre a SQL Server con usuario y contraseña
debe llenar `DB_USER` y `DB_PASSWORD` en su `.env` y quitar `Trusted_Connection=yes` de `config/settings.py` en su copia local.