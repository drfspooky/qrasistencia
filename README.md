# Sistema de Control de Asistencia QR MVP

Este proyecto es un Producto Mínimo Viable (MVP) completamente funcional para el control de asistencia académica de alumnos a través de códigos QR dinámicos y temporales. El sistema incluye un backend robusto con Django REST Framework y base de datos PostgreSQL, un panel administrativo y de reportes, y una aplicación cliente multiplataforma desarrollada en Flutter para docentes y alumnos.

---

## 🛠️ Stack Tecnológico

* **Backend:** Python 3.12, Django 5.0, Django REST Framework (DRF), JWT (SimpleJWT)
* **Base de Datos:** PostgreSQL (con Docker), SQLite (como fallback para desarrollo local rápido)
* **API Docs:** OpenAPI 3.0 mediante `drf-spectacular`
* **Frontend Móvil / Multiplataforma:** Flutter, Riverpod (para gestión de estados), `go_router` (enrutamiento declarativo), `mobile_scanner` (escaneo de cámara), `qr_flutter` (proyección de QR)
* **Contenedores:** Docker y `docker-compose`

---

## 📁 Estructura del Proyecto

```
/Asistencia QR
  ├── docker-compose.yml       # Orquestación de contenedores (Backend + Postgres)
  ├── README.md                # Guía de instalación y ejecución (este archivo)
  ├── backend/                 # Código fuente del servidor Django
  │   ├── Dockerfile
  │   ├── requirements.txt
  │   ├── manage.py
  │   ├── config/              # Configuración general del proyecto
  │   └── apps/                # Aplicaciones Django modulares
  │       ├── users/           # Roles, usuarios y autenticación JWT
  │       ├── academics/       # Cursos, secciones, matrículas y aulas
  │       ├── attendance/      # Sesiones, marcas QR, geofencing y justificaciones
  │       └── reports/         # Generación de reportes PDF y Excel, alertas semáforo
  └── frontend/                # Aplicación Flutter
      ├── pubspec.yaml         # Dependencias de Flutter
      └── lib/                 # Estructura limpia de la app móvil
          ├── core/            # Cliente API, enrutador y almacenamiento seguro
          ├── features/        # Módulos de la aplicación
          │   ├── auth/        # Splash y Login
          │   ├── student/     # Dashboard alumno, escáner e historial
          │   ├── teacher/     # Dashboard docente, proyector QR y edición manual
          │   └── admin/       # Dashboard administrativo y descargas de reportes
          └── main.dart        # Punto de entrada de la aplicación
```

---

## 🚀 Instrucciones de Ejecución

### Opción A: Ejecución con Docker Compose (Recomendado)

Asegúrate de tener instalado **Docker Desktop** y ejecutándose en tu máquina.

1. **Construir y levantar los contenedores:**
   ```bash
   docker-compose up --build
   ```
   Esto levantará el servidor backend en `http://localhost:8000` y la base de datos PostgreSQL en el puerto `5432`.

2. **Ejecutar migraciones de la base de datos:**
   En otra pestaña de la terminal, corre:
   ```bash
   docker-compose exec web python manage.py migrate
   ```

3. **Cargar datos seed de prueba:**
   ```bash
   docker-compose exec web python manage.py seed_data
   ```
   *Nota: Este comando creará 1 institución, 1 campus, 5 cursos, 5 docentes, 50 estudiantes, clases pasadas y semáforos de asistencia simulados.*

4. **Correr los tests unitarios:**
   ```bash
   docker-compose exec web python manage.py test
   ```

---

### Opción B: Ejecución Local Directa (Sin Docker - Base de datos SQLite automática)

Si prefieres correrlo sin Docker, el backend usará automáticamente una base de datos local SQLite para facilitar las pruebas rápidas.

1. **Configurar el Backend:**
   ```bash
   cd backend
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   python manage.py makemigrations
   python manage.py migrate
   python manage.py seed_data
   python manage.py runserver
   ```
   El servidor backend estará listo en `http://10.0.2.2:8000` (para el emulador de Android) y `http://localhost:8000` (para web/desktop).

2. **Configurar y ejecutar el Frontend (Flutter):**
   Asegúrate de tener un emulador Android activo o usar Flutter Web.
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```

---

## 👥 Cuentas de Acceso para Pruebas

El comando `seed_data` crea las siguientes credenciales para probar todos los roles en la app de Flutter:

| Rol | Correo Electrónico | Contraseña | Detalle |
| :--- | :--- | :--- | :--- |
| **Administrador** | `admin@demo.com` | `password` | Vista general de reportes, semáforos y exportaciones. |
| **Docente 1** | `docente1@demo.com` | `password` | Asignado al curso "POO" e "EDA". Puede abrir QR y editar asistencias. |
| **Alumno 1** | `alumno1@demo.com` | `password` | Matriculado en "POO" y "DAM". Puede escanear y enviar justificaciones. |

*Nota: La pantalla de Login incluye botones de acceso directo para rellenar estas credenciales con un solo toque.*

---

## 🔒 Flujo de Demostración Mínimo Viable (Paso a Paso)

Para validar el funcionamiento completo de extremo a extremo:

1. **Inicio de sesión del Docente:**
   * Inicia sesión en la aplicación Flutter como `docente1@demo.com` / `password`.
   * En el dashboard verás la sesión activa asignada para el día de hoy (curso *Programación Orientada a Objetos*).
   * Presiona **Proyectar QR**.
   * Se abrirá la pantalla del proyector mostrando el **código QR dinámico** (que se regenera automáticamente cada 15 segundos).

2. **Escaneo del Alumno:**
   * Abre la app en otro dispositivo, pestaña web o emulador e inicia sesión como `alumno1@demo.com` / `password`.
   * En el dashboard, presiona **Escanear QR**.
   * Si usas la cámara, escanea el QR proyectado. Si estás en web/simulador sin cámara, **copia el token UUID** que se muestra debajo del QR del docente y pégalo en la sección "Pruebas sin Cámara".
   * El sistema validará la geolocalización, matrícula y hora de tolerancia, registrándote como **Presente** o **Tardanza** según corresponda.

3. **Verificación del Docente (Tiempo Real):**
   * En la pantalla del Docente, verás que la lista de asistencia se actualiza automáticamente mostrando al *Estudiante 1* como Presente con su hora exacta de marcación.
   * Puedes presionar el ícono de edición (lápiz) al lado del alumno para forzar manualmente un cambio de estado (ej. cambiar a *Retiro Anticipado*) agregando una justificación que quedará grabada en el log de auditoría.

4. **Revisión y Descarga de Reportes (Administrador):**
   * Inicia sesión como `admin@demo.com` / `password`.
   * Visualizarás las tarjetas KPI generales (Asistencia Promedio, alumnos en riesgo).
   * Al final del listado de cursos, presiona **Matriz Excel** para descargar una hoja de cálculo completa con la cuadrícula de asistencias por fecha, o **Exportar PDF** para un reporte listo para imprimir.
