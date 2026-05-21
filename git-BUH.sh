#!/usr/bin/env bash
# =============================================================================
# git-BUH — Práctica interactiva de Git 
# =============================================================================
# Menú con opción 0 (configurar Git/Ubuntu, SSH y guía GitHub) y ejercicios 1–10.
# Cada ejercicio tiene guía en pantalla y verificación automática antes de marcar ✓.
#
# Estructura del código:
#   1. Constantes y salida con color
#   2. Utilidades generales y comprobación de Git
#   3. Módulo SSH (varias claves / varios usuarios Linux)
#   4. Progreso (.git-buh-progreso) y ayudantes Git
#   5. verificar_ejercicio_N — comprobaciones sin intervención del usuario
#   6. ejercicio_N — guías interactivas
#   7. Menú, README, opción 0 y bucle principal
# =============================================================================

set -euo pipefail  # Falla ante errores, variables no definidas y pipes rotos

# --- Rutas y nombres globales ---
NOMBRE_PROGRAMA="git-BUH"
DIR_TRABAJO="$(pwd)"                    # Carpeta desde la que el alumno practica (sandbox)
ARCHIVO_PROGRESO="${DIR_TRABAJO}/.git-buh-progreso"   # Una línea por ejercicio completado (0–10)
ARCHIVO_PROGRESO_ANTIGUO="${DIR_TRABAJO}/.ejercicios-git-progreso"
NOMBRE_SCRIPT="$(basename "$0")"
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Donde está instalado git-BUH
ARCHIVO_README="${DIR_SCRIPT}/README.md"

# --- Colores (degradación sin TTY: si no hay terminal, cadenas vacías) ---
if [[ -t 1 ]] && command -v tput &>/dev/null; then
  C_OK=$(tput setaf 2)
  C_ERR=$(tput setaf 1)
  C_INFO=$(tput setaf 4)
  C_WARN=$(tput setaf 3)
  C_BOLD=$(tput bold)
  C_RESET=$(tput sgr0)
else
  C_OK= C_ERR= C_INFO= C_WARN= C_BOLD= C_RESET=
fi

# --- Mensajes formateados al usuario ---
mensaje_ok()   { printf '%s[OK]%s %s\n' "$C_OK" "$C_RESET" "$*"; }
mensaje_error()  { printf '%s[ERROR]%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; }
mensaje_info() { printf '%s[INFO]%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
mensaje_aviso() { printf '%s[AVISO]%s %s\n' "$C_WARN" "$C_RESET" "$*"; }

# Espera confirmación cuando el alumno ejecute comandos en su terminal
pausa() {
  read -r -p "Pulsa Enter cuando hayas terminado este paso..."
}

# Compatibilidad con versiones que guardaban progreso en .ejercicios-git-progreso
migrar_progreso_antiguo() {
  if [[ -f "$ARCHIVO_PROGRESO_ANTIGUO" && ! -f "$ARCHIVO_PROGRESO" ]]; then
    cp "$ARCHIVO_PROGRESO_ANTIGUO" "$ARCHIVO_PROGRESO"
    mensaje_info "Progreso migrado desde .ejercicios-git-progreso"
  fi
}

# Comprueba que git está en PATH; usado antes de ejercicios 1–10 (no en opción 0)
requerir_git() {
  if ! command -v git &>/dev/null; then
    mensaje_error "Git no está instalado. Usa la opción 0 del menú para instalarlo y configurarlo."
    return 1
  fi
  return 0
}

# Opción 0 exige user.name y user.email globales para marcar configuración completa
tiene_identidad_git() {
  command -v git &>/dev/null || return 1
  [[ -n "$(git config --global --get user.name 2>/dev/null || true)" ]] &&
    [[ -n "$(git config --global --get user.email 2>/dev/null || true)" ]]
}

# Recordatorio en ejercicios 6 y 9 si aún no pasaron por la opción 0
aviso_si_falta_config() {
  if ! tiene_identidad_git; then
    mensaje_aviso "Completa la opción 0 del menú (user.name y user.email) antes de seguir."
  fi
}

# Solo en Ubuntu/Debian ofrecemos instalación automática con apt
es_ubuntu_o_debian() {
  [[ -f /etc/os-release ]] || return 1
  local id
  id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  [[ "$id" == "ubuntu" || "$id" == "debian" ]]
}

# Preferencia SSH por usuario Linux (no mezcla claves entre usuarios del sistema)
DIR_CONFIG_BUH="${HOME}/.config/git-buh"
ARCHIVO_CLAVE_SSH_PREF="${DIR_CONFIG_BUH}/clave-ssh-preferida"   # Ruta clave privada
ARCHIVO_HOST_SSH_GITHUB="${DIR_CONFIG_BUH}/host-github"           # github.com o alias de ~/.ssh/config

tiene_cliente_ssh() {
  command -v ssh &>/dev/null && command -v ssh-keygen &>/dev/null
}

# Instala openssh-client con apt si el usuario confirma (Ubuntu/Debian)
instalar_openssh_client() {
  if tiene_cliente_ssh; then
    mensaje_ok "Cliente SSH disponible: $(ssh -V 2>&1 | head -1)"
    return 0
  fi
  mensaje_aviso "OpenSSH (ssh, ssh-keygen) no está instalado. Es necesario para conectar con GitHub por SSH."
  if es_ubuntu_o_debian; then
    echo "  sudo apt-get install -y openssh-client"
    echo
    read -r -p "¿Instalar openssh-client ahora? (s/N): " instalar_ssh
    if [[ "${instalar_ssh,,}" == "s" || "${instalar_ssh,,}" == "si" ]]; then
      if sudo apt-get install -y openssh-client; then
        mensaje_ok "openssh-client instalado."
        return 0
      fi
      mensaje_error "No se pudo instalar openssh-client."
      return 1
    fi
  else
    echo "Instala el paquete openssh-client de tu distribución."
  fi
  return 1
}

# Imprime una ruta por línea: todas las *.pub del usuario actual (whoami)
listar_claves_publicas_ssh() {
  local dir="${HOME}/.ssh"
  [[ -d "$dir" ]] || return 0
  local f
  shopt -s nullglob
  for f in "$dir"/*.pub; do
    printf '%s\n' "$f"
  done
  shopt -u nullglob
}

ruta_clave_privada_desde_publica() {
  local pub=$1
  printf '%s' "${pub%.pub}"
}

# Persiste qué clave y qué Host usar en pruebas ssh -T y verificación ejercicio 9
guardar_preferencia_ssh() {
  mkdir -p "$DIR_CONFIG_BUH"
  printf '%s\n' "$1" > "$ARCHIVO_CLAVE_SSH_PREF"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" > "$ARCHIVO_HOST_SSH_GITHUB"
  else
    printf '%s\n' 'github.com' > "$ARCHIVO_HOST_SSH_GITHUB"
  fi
}

# Variables globales usadas por verificar_ejercicio_9, ejercicio_6 y guías
cargar_preferencia_ssh() {
  CLAVE_SSH_PRIVADA=""
  HOST_SSH_GITHUB="github.com"
  if [[ -f "$ARCHIVO_CLAVE_SSH_PREF" ]]; then
    CLAVE_SSH_PRIVADA=$(<"$ARCHIVO_CLAVE_SSH_PREF")
    [[ -f "$CLAVE_SSH_PRIVADA" ]] || CLAVE_SSH_PRIVADA=""
  fi
  if [[ -f "$ARCHIVO_HOST_SSH_GITHUB" ]]; then
    HOST_SSH_GITHUB=$(<"$ARCHIVO_HOST_SSH_GITHUB")
    [[ -n "$HOST_SSH_GITHUB" ]] || HOST_SSH_GITHUB="github.com"
  fi
}

# Prueba no interactiva: BatchMode evita pedir contraseña; IdentitiesOnly fuerza una sola clave
# host puede ser "github.com" o un alias (ej. github.com-trabajo) definido en ~/.ssh/config
probar_conexion_github_ssh() {
  local host="${1:-github.com}"
  local clave_priv="${2:-}"
  local args=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T "git@${host}")
  if [[ -n "$clave_priv" && -f "$clave_priv" ]]; then
    args=(-i "$clave_priv" -o IdentitiesOnly=yes "${args[@]}")
  fi
  ssh "${args[@]}" 2>&1 || true
}

# Texto educativo: varios usuarios Linux vs varias cuentas GitHub en un mismo usuario
guia_ssh_varios_usuarios() {
  imprimir_cabecera "Varios usuarios y varias claves SSH en el mismo equipo"
  echo "En un mismo PC pueden coexistir:"
  echo
  echo "  A) Varios usuarios de Linux (juan, maria…)"
  echo "     Cada uno tiene su carpeta ~/.ssh/ con sus propias claves."
  echo "     Ejecuta git-BUH con el usuario con el que vayas a hacer commits."
  echo
  echo "  B) Un solo usuario Linux con varias cuentas de GitHub"
  echo "     Usa un archivo de clave distinto por cuenta y define alias en ~/.ssh/config:"
  echo
  echo "     Host github.com-trabajo"
  echo "       HostName github.com"
  echo "       User git"
  echo "       IdentityFile ~/.ssh/id_ed25519_trabajo"
  echo "       IdentitiesOnly yes"
  echo
  echo "     Host github.com-personal"
  echo "       HostName github.com"
  echo "       User git"
  echo "       IdentityFile ~/.ssh/id_ed25519_personal"
  echo "       IdentitiesOnly yes"
  echo
  echo "     Remoto del repo (ejemplo cuenta trabajo):"
  echo "       git@github.com-trabajo:ORGANIZACION/repo.git"
  echo
  echo "  Preferencia de este programa (usuario actual: $(whoami)):"
  echo "    Clave:  ${ARCHIVO_CLAVE_SSH_PREF}"
  echo "    Host:   ${ARCHIVO_HOST_SSH_GITHUB}"
  echo
}

# Menú interactivo: elegir clave existente, crear una nueva con nombre libre, o saltar
# Si hay varias .pub, evita asumir id_ed25519 por defecto (equipos compartidos)
seleccionar_o_crear_clave_ssh() {
  local email="${1:-}"
  local claves=()
  local c ruta_pub ruta_priv indice nombre_nuevo host_alias

  mapfile -t claves < <(listar_claves_publicas_ssh)

  imprimir_cabecera "Claves SSH para GitHub (usuario: $(whoami))"
  echo "Directorio: ${HOME}/.ssh/"
  echo

  if [[ ${#claves[@]} -gt 0 ]]; then
    mensaje_info "Claves públicas encontradas en este usuario:"
    for indice in "${!claves[@]}"; do
      echo "  $((indice + 1))) ${claves[$indice]}"
    done
    echo "  n) Generar una clave nueva (nombre personalizado)"
    echo "  s) Saltar por ahora (podrás hacerlo en el ejercicio 9)"
    echo
    read -r -p "Elige clave para GitHub o opción [1-${#claves[@]}/n/s]: " eleccion

    if [[ "${eleccion,,}" == "s" ]]; then
      return 0
    fi

    if [[ "${eleccion,,}" == "n" ]]; then
      :  # Caer al bloque de generación ssh-keygen más abajo
    elif [[ "$eleccion" =~ ^[0-9]+$ ]] && (( eleccion >= 1 && eleccion <= ${#claves[@]} )); then
      ruta_pub="${claves[$((eleccion - 1))]}"
      ruta_priv=$(ruta_clave_privada_desde_publica "$ruta_pub")
      echo
      read -r -p "¿Alias Host en ~/.ssh/config para esta clave? (vacío = github.com): " host_alias
      host_alias="${host_alias:-github.com}"
      guardar_preferencia_ssh "$ruta_priv" "$host_alias"
      mensaje_ok "Preferencia guardada: clave ${ruta_priv}, host ${host_alias}"
      echo "Añade la clave pública en GitHub: https://github.com/settings/keys"
      echo "  cat ${ruta_pub}"
      return 0
    else
      mensaje_aviso "Opción no válida."
      return 0
    fi
  else
    mensaje_aviso "No hay claves .pub en ~/.ssh de este usuario."
    read -r -p "¿Generar una clave nueva para GitHub? (s/N): " crear
    [[ "${crear,,}" == "s" || "${crear,,}" == "si" ]] || return 0
  fi

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true
  nombre_nuevo="id_ed25519_github_$(whoami)"
  read -r -p "Nombre del archivo de clave [${nombre_nuevo}]: " nombre_input
  [[ -n "$nombre_input" ]] && nombre_nuevo="$nombre_input"
  ruta_priv="${HOME}/.ssh/${nombre_nuevo}"

  if [[ -f "$ruta_priv" ]]; then
    mensaje_aviso "Ya existe ${ruta_priv}. Elige otra clave en la lista o borra/renombra ese archivo."
    return 0
  fi

  local comentario="${email:-$(whoami)@$(hostname -s 2>/dev/null || echo localhost)}"
  read -r -p "Comentario para la clave (-C) [${comentario}]: " comentario_input
  [[ -n "$comentario_input" ]] && comentario="$comentario_input"

  echo
  mensaje_info "Generando clave (puedes dejar passphrase vacía para práctica local)..."
  ssh-keygen -t ed25519 -C "$comentario" -f "$ruta_priv"

  ruta_pub="${ruta_priv}.pub"
  echo
  read -r -p "¿Alias Host en ~/.ssh/config? (ej. github.com-$(whoami), vacío=github.com): " host_alias
  host_alias="${host_alias:-github.com}"
  guardar_preferencia_ssh "$ruta_priv" "$host_alias"
  mensaje_ok "Clave creada: ${ruta_pub}"
  echo "Copia en GitHub → Settings → SSH keys:"
  echo "  cat ${ruta_pub}"
  if [[ "$host_alias" != "github.com" ]]; then
    echo
    echo "Añade en ~/.ssh/config (si no existe el bloque Host):"
    echo "  Host ${host_alias}"
    echo "    HostName github.com"
    echo "    User git"
    echo "    IdentityFile ${ruta_priv}"
    echo "    IdentitiesOnly yes"
    echo
    echo "URL remota del repo: git@${host_alias}:USUARIO/REPO.git"
  fi
}

# Orquesta instalación SSH, guía multi-usuario, selección de clave y prueba opcional
configurar_ssh_github() {
  imprimir_cabecera "SSH local (requisito para GitHub por SSH)"
  echo "Para git@github.com:USUARIO/REPO necesitas:"
  echo "  1. Cliente OpenSSH (ssh, ssh-keygen) instalado"
  echo "  2. Al menos una clave en ~/.ssh/ de ESTE usuario de Linux ($(whoami))"
  echo "  3. La clave pública registrada en la cuenta de GitHub que vayas a usar"
  echo

  instalar_openssh_client || {
    mensaje_aviso "Sin cliente SSH no podrás usar URLs git@github.com hasta instalarlo."
    return 0
  }

  guia_ssh_varios_usuarios

  local email
  email=$(git config --global --get user.email 2>/dev/null || true)
  seleccionar_o_crear_clave_ssh "$email"

  cargar_preferencia_ssh
  if [[ -n "$CLAVE_SSH_PRIVADA" ]]; then
    echo
    read -r -p "¿Probar conexión SSH con GitHub ahora? (s/N): " probar
    if [[ "${probar,,}" == "s" || "${probar,,}" == "si" ]]; then
      local salida
      salida=$(probar_conexion_github_ssh "$HOST_SSH_GITHUB" "$CLAVE_SSH_PRIVADA")
      echo "$salida"
      if echo "$salida" | grep -qiE 'successfully authenticated|Hi [A-Za-z0-9_-]+'; then
        mensaje_ok "Conexión SSH con GitHub correcta (host: ${HOST_SSH_GITHUB})."
      else
        mensaje_aviso "La prueba no confirmó autenticación. Registra la clave en GitHub o revisa ~/.ssh/config."
        echo "  https://github.com/settings/keys"
      fi
    fi
  fi
}

# --- Progreso (archivo de texto: una línea "0", "1", … "10" por ejercicio) ---
ejercicio_completado() {
  local n=$1
  [[ -f "$ARCHIVO_PROGRESO" ]] && grep -qx "$n" "$ARCHIVO_PROGRESO" 2>/dev/null
}

# Añade el número de ejercicio al archivo de progreso si aún no estaba
marcar_ejercicio_completado() {
  local n=$1
  touch "$ARCHIVO_PROGRESO"
  if ! ejercicio_completado "$n"; then
    echo "$n" >> "$ARCHIVO_PROGRESO"
  fi
}

# Línea del menú: [0✓] [1 ] [2✓] … — la opción 0 es configuración, 1–10 ejercicios
indicador_progreso() {
  local salida=""
  local i
  if ejercicio_completado 0; then salida+="[0✓] "; else salida+="[0 ] "; fi
  for i in $(seq 1 10); do
    if ejercicio_completado "$i"; then
      salida+="[${i}✓] "
    else
      salida+="[${i} ] "
    fi
  done
  printf '%s\n' "$salida"
}

# --- Ayudantes Git (compatibles con main/master y repos sin commits) ---
en_repositorio_git() {
  git rev-parse --git-dir &>/dev/null
}

# Detecta main o master según HEAD, refs existentes o fallback "main"
rama_por_defecto() {
  if en_repositorio_git; then
    local ref
    ref=$(git symbolic-ref -q HEAD 2>/dev/null || true)
    if [[ -n "$ref" ]]; then
      basename "$ref"
      return
    fi
    if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
      echo main
      return
    fi
    if git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
      echo master
      return
    fi
  fi
  echo main
}

# 0 si no hay commits aún (rev-parse HEAD fallaría)
contar_commits() {
  if en_repositorio_git && git rev-parse HEAD &>/dev/null 2>&1; then
    git rev-list --count HEAD
  else
    echo 0
  fi
}

# Llama dinámicamente a verificar_ejercicio_N; bucle hasta éxito o "volver al menú"
ejecutar_verificacion() {
  local n=$1
  local funcion="verificar_ejercicio_${n}"
  while true; do
    if "$funcion"; then
      return 0
    fi
    echo
    echo "  1) Reintentar verificación"
    echo "  2) Volver al menú"
    read -r -p "Opción: " opcion
    case "$opcion" in
      1) continue ;;
      2) return 1 ;;
      *) mensaje_aviso "Opción no válida." ;;
    esac
  done
}

# Título centrado entre líneas de iguales (separador visual)
imprimir_cabecera() {
  local title=$1
  echo
  printf '%s%s%s\n' "$C_BOLD" "═══════════════════════════════════════════════════════════" "$C_RESET"
  printf '%s  %s%s\n' "$C_BOLD" "$title" "$C_RESET"
  printf '%s%s%s\n' "$C_BOLD" "═══════════════════════════════════════════════════════════" "$C_RESET"
  echo
}

# Al arrancar: advierte si la carpeta no está vacía o ya tiene .git; pide confirmación
aviso_directorio_trabajo() {
  imprimir_cabecera "Comprobación del directorio de trabajo"
  mensaje_info "Directorio actual: ${DIR_TRABAJO}"
  echo

  local cuenta=0
  shopt -s nullglob dotglob
  local entradas=(*)
  shopt -u nullglob dotglob
  for e in "${entradas[@]}"; do
    [[ "$e" == ".git-buh-progreso" || "$e" == ".ejercicios-git-progreso" ]] && continue
    ((cuenta++)) || true
  done

  if [[ $cuenta -gt 0 ]]; then
    mensaje_aviso "Este directorio no está vacío (${cuenta} elemento(s) visible(s))."
    mensaje_aviso "Se recomienda practicar en una carpeta dedicada, por ejemplo:"
    echo "    mkdir -p ~/practica-git && cd ~/practica-git"
    echo "    cp ruta/a/${NOMBRE_SCRIPT} . && ./${NOMBRE_SCRIPT}"
    echo
  fi

  if [[ -d .git ]]; then
    mensaje_aviso "Ya existe un repositorio Git (.git) en este directorio."
    echo "Los ejercicios continuarán sobre este repositorio."
    echo
  fi

  read -r -p "¿Continuar en este directorio? (s/N): " confirmar
  [[ "${confirmar,,}" == "s" || "${confirmar,,}" == "si" || "${confirmar,,}" == "y" ]] || exit 0
}

# ═══════════════════════════════════════════════════════════════
# VERIFICADORES
# Cada función rellena el array errores[]; si está vacío, marca el ejercicio ✓
# ═══════════════════════════════════════════════════════════════

# Comprueba .git y que git rev-parse funcione
verificar_ejercicio_1() {
  local errores=()
  if [[ ! -d .git ]]; then
    errores+=("No existe el directorio .git — ejecuta: git init")
  fi
  if ! git rev-parse --git-dir &>/dev/null; then
    errores+=("git rev-parse --git-dir falló — el repositorio no es válido")
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 1
    mensaje_ok "Ejercicio 1 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# ≥5 commits y árbol de trabajo limpio (sin cambios pendientes)
verificar_ejercicio_2() {
  local errores=()
  local n
  if ! en_repositorio_git; then
    errores+=("Primero completa el ejercicio 1 (git init)")
  else
    n=$(contar_commits)
    if [[ "$n" -lt 5 ]]; then
      errores+=("Necesitas al menos 5 commits (tienes ${n}). Usa: git add . && git commit -m \"mensaje\"")
    fi
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      errores+=("Hay cambios sin commitear. Haz commit o descártalos antes de verificar.")
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 2
    mensaje_ok "Ejercicio 2 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Ramas con nombres fijos feature/login y feature/docs (≥3 ramas en total)
verificar_ejercicio_3() {
  local errores=()
  local branch_count
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git inicializado")
  else
    if ! git show-ref --verify --quiet refs/heads/feature/login 2>/dev/null; then
      errores+=("Falta la rama feature/login — créala con: git switch -c feature/login")
    fi
    if ! git show-ref --verify --quiet refs/heads/feature/docs 2>/dev/null; then
      errores+=("Falta la rama feature/docs — créala con: git switch -c feature/docs")
    fi
    branch_count=$(git branch --format='%(refname:short)' | wc -l)
    if [[ "$branch_count" -lt 3 ]]; then
      errores+=("Necesitas al menos 3 ramas locales (tienes ${branch_count})")
    fi
    local def
    def=$(rama_por_defecto)
    if ! git show-ref --verify --quiet "refs/heads/${def}" 2>/dev/null; then
      errores+=("Debe existir la rama principal (${def})")
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 3
    mensaje_ok "Ejercicio 3 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# feature/login debe ser ancestro de HEAD (merge hecho en la rama principal)
verificar_ejercicio_4() {
  local errores=()
  local def
  def=$(rama_por_defecto)
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git")
  else
    if ! git show-ref --verify --quiet refs/heads/feature/login 2>/dev/null; then
      errores+=("Falta la rama feature/login")
    fi
    if ! git merge-base --is-ancestor feature/login HEAD 2>/dev/null; then
      errores+=("feature/login no está fusionada en la rama actual — en ${def} ejecuta: git merge feature/login")
    fi
    local current
    current=$(git branch --show-current 2>/dev/null || true)
    if [[ "$current" != "$def" ]]; then
      mensaje_aviso "Estás en la rama '${current:-detached}'. Se esperaba estar en ${def} tras el merge."
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 4
    mensaje_ok "Ejercicio 4 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Sin merge a medias (MERGE_HEAD, UU/AA/DD) y evidencia de conflicto resuelto en el historial
verificar_ejercicio_5() {
  local errores=()
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git")
  else
    if [[ -f .git/MERGE_HEAD ]]; then
      errores+=("Hay un merge en progreso — resuelve conflictos, git add y git commit")
    fi
    local unmerged
    unmerged=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
    if [[ -n "$unmerged" ]]; then
      errores+=("Archivos sin fusionar: ${unmerged}")
    fi
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      local st
      st=$(git status --porcelain)
      if echo "$st" | grep -qE '^UU|^AA|^DD'; then
        errores+=("Siguen existiendo conflictos sin resolver en git status")
      fi
    fi
    # Cualquiera de estas señales indica que practicó resolución de conflictos
    local resolved=0
    if git ls-files --error-unmatch conflicto.txt &>/dev/null 2>&1; then
      resolved=1
    fi
    if git merge-base --is-ancestor conflict-demo HEAD 2>/dev/null; then
      resolved=1
    fi
    if git log --oneline 2>/dev/null | grep -qiE 'conflict-demo|conflicto|Resolver conflicto'; then
      resolved=1
    fi
    if [[ $resolved -eq 0 ]]; then
      errores+=("No hay evidencia de un conflicto resuelto — usa la preparación automática o merge conflict-demo")
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 5
    mensaje_ok "Ejercicio 5 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Remoto origin y rama principal con upstream (git push -u); ls-remote es comprobación blanda
verificar_ejercicio_6() {
  local errores=()
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git")
  else
    local url
    if ! url=$(git remote get-url origin 2>/dev/null); then
      errores+=("Falta el remoto 'origin' — usa: git remote add origin <URL>")
    elif [[ -z "$url" ]]; then
      errores+=("La URL de origin está vacía")
    fi
    # upstream_ok: rama enlazada a origin/main (o similar) tras push -u
    local def upstream_ok=0
    def=$(rama_por_defecto)
    if git rev-parse --abbrev-ref "${def}@{upstream}" &>/dev/null 2>&1; then
      upstream_ok=1
    elif git branch -vv 2>/dev/null | grep -q '\[origin/'; then
      upstream_ok=1
    fi
    if [[ $upstream_ok -eq 0 ]]; then
      errores+=("La rama ${def} no tiene upstream — ejecuta: git push -u origin ${def}")
    fi
    if [[ $upstream_ok -eq 1 ]] && command -v git &>/dev/null; then
      if ! git ls-remote origin HEAD &>/dev/null 2>&1; then
        mensaje_aviso "No se pudo comprobar el remoto (red o permisos). Se acepta si origin y upstream están configurados."
      fi
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 6
    mensaje_ok "Ejercicio 6 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Simula dos desarrolladores: bare + clones hermanos; HEAD de dev-a y dev-b deben coincidir
verificar_ejercicio_7() {
  local errores=()
  local parent bare dev_a dev_b
  parent="$(dirname "$DIR_TRABAJO")"
  bare="${parent}/pareja-repo.git"
  dev_a="${parent}/dev-a"
  dev_b="${parent}/dev-b"

  if [[ ! -d "$bare" ]]; then
    errores+=("No existe el repositorio bare: ${bare}")
  fi
  if [[ ! -d "$dev_a/.git" ]] && [[ ! -f "$dev_a/.git" ]]; then
    errores+=("No existe el clon de dev-a en: ${dev_a}")
  fi
  if [[ ! -d "$dev_b/.git" ]] && [[ ! -f "$dev_b/.git" ]]; then
    errores+=("No existe el clon de dev-b en: ${dev_b}")
  fi

  if [[ ${#errores[@]} -eq 0 ]]; then
    local hash_a hash_b
    hash_a=$(git -C "$dev_a" rev-parse HEAD 2>/dev/null || echo "")
    hash_b=$(git -C "$dev_b" rev-parse HEAD 2>/dev/null || echo "")
    if [[ -z "$hash_a" || -z "$hash_b" ]]; then
      errores+=("dev-a o dev-b no tienen commits")
    elif [[ "$hash_a" != "$hash_b" ]]; then
      errores+=("dev-a y dev-b no están sincronizados (HEAD distinto)")
      errores+=("  dev-a: ${hash_a:0:8}")
      errores+=("  dev-b: ${hash_b:0:8}")
      errores+=("Ejecuta git pull en el clon que vaya detrás")
    fi
    local log_count
    log_count=$(git -C "$bare" rev-list --count --all 2>/dev/null || echo 0)
    if [[ "$log_count" -lt 2 ]]; then
      errores+=("El bare debe tener al menos 2 commits del flujo en pareja (tiene ${log_count})")
    fi
    if ! git -C "$bare" log --oneline --all 2>/dev/null | grep -qiE 'dev-a|dev-b|persona'; then
      mensaje_aviso "Se recomienda usar mensajes de commit que identifiquen a dev-a y dev-b."
    fi
  fi

  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 7
    mensaje_ok "Ejercicio 7 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# .gitignore activo: prueba.log ignorado y no trackeado en el índice
verificar_ejercicio_8() {
  local errores=()
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git")
  else
    if [[ ! -f .gitignore ]]; then
      errores+=("Falta el archivo .gitignore en la raíz del proyecto")
    fi
    if ! git check-ignore -q prueba.log 2>/dev/null; then
      errores+=("prueba.log no está siendo ignorado — añade *.log a .gitignore y crea el archivo")
    fi
    if git ls-files --error-unmatch prueba.log &>/dev/null 2>&1; then
      errores+=("prueba.log está en el índice — no debe estar trackeado")
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 8
    mensaje_ok "Ejercicio 8 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# OpenSSH + al menos una .pub; prueba git@HOST con clave preferida o la primera encontrada
verificar_ejercicio_9() {
  local errores=()
  local pubkey="" claves=() ssh_out

  if ! tiene_cliente_ssh; then
    errores+=("Falta el cliente OpenSSH (ssh, ssh-keygen). Opción 0 o: sudo apt install openssh-client")
  fi

  mapfile -t claves < <(listar_claves_publicas_ssh)
  if [[ ${#claves[@]} -eq 0 ]]; then
    errores+=("No hay claves públicas en ~/.ssh/ del usuario $(whoami)")
    errores+=("Genera una con la opción 0 o: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github -C \"tu-email\"")
  fi

  cargar_preferencia_ssh
  if [[ -n "$CLAVE_SSH_PRIVADA" && -f "$CLAVE_SSH_PRIVADA" ]]; then
    pubkey="${CLAVE_SSH_PRIVADA}.pub"
  elif [[ ${#claves[@]} -gt 0 ]]; then
    # Sin preferencia guardada: fallback a la primera clave (puede fallar si hay varias cuentas)
    pubkey="${claves[0]}"
    CLAVE_SSH_PRIVADA=$(ruta_clave_privada_desde_publica "$pubkey")
    HOST_SSH_GITHUB="github.com"
  fi

  if [[ ${#errores[@]} -eq 0 ]]; then
    ssh_out=$(probar_conexion_github_ssh "${HOST_SSH_GITHUB:-github.com}" "${CLAVE_SSH_PRIVADA:-}")
    if ! echo "$ssh_out" | grep -qiE 'successfully authenticated|Hi [A-Za-z0-9_-]+'; then
      errores+=("La prueba SSH con GitHub no fue exitosa (host: ${HOST_SSH_GITHUB:-github.com})")
      errores+=("Salida: ${ssh_out:-sin respuesta}")
      errores+=("Registra la clave en: https://github.com/settings/keys")
      errores+=("Clave pública: ${pubkey:-desconocida}")
      errores+=("Si tienes varias cuentas, revisa ~/.ssh/config y la preferencia en ${ARCHIVO_CLAVE_SSH_PREF}")
    fi
  fi

  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 9
    mensaje_ok "Ejercicio 9 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Flujo release: ≥8 commits, feature/release-prep fusionada con --no-ff, tag v1.0.0
verificar_ejercicio_10() {
  local errores=()
  local def n merges
  if ! en_repositorio_git; then
    errores+=("No hay repositorio Git")
  else
    def=$(rama_por_defecto)
    n=$(contar_commits)
    if [[ "$n" -lt 8 ]]; then
      errores+=("Se requieren al menos 8 commits en el historial (tienes ${n})")
    fi
    if ! git show-ref --verify --quiet refs/heads/feature/release-prep 2>/dev/null; then
      if ! git log --all --oneline 2>/dev/null | grep -q 'release-prep\|feature/release'; then
        errores+=("Falta la rama feature/release-prep (o su historial en el merge)")
      fi
    fi
    if ! git rev-parse v1.0.0 &>/dev/null 2>&1; then
      errores+=("Falta el tag anotado v1.0.0 — usa: git tag -a v1.0.0 -m \"Primera release\"")
    fi
    merges=$(git log "${def}" --merges --oneline 2>/dev/null | wc -l)
    if [[ "$merges" -lt 1 ]]; then
      errores+=("No hay merge commit en ${def} — fusiona con: git merge --no-ff feature/release-prep")
    fi
    if git show-ref --verify --quiet refs/heads/feature/release-prep 2>/dev/null; then
      if ! git merge-base --is-ancestor feature/release-prep "${def}" 2>/dev/null; then
        errores+=("feature/release-prep debe estar fusionada en ${def}")
      fi
    fi
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 10
    mensaje_ok "Ejercicio 10 completado."
    return 0
  fi
  mensaje_error "Aún no se cumplen los requisitos:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# ═══════════════════════════════════════════════════════════════
# EJERCICIOS (guía interactiva; cada uno termina en ejecutar_verificacion N)
# ═══════════════════════════════════════════════════════════════

# git init en DIR_TRABAJO; puede ejecutar git init por el alumno si confirma
ejercicio_1() {
  imprimir_cabecera "Ejercicio 1: Crear un repositorio local"
  echo "Objetivo: inicializar un repositorio Git en este directorio."
  echo
  echo "Un repositorio local guarda el historial en la carpeta oculta .git/"
  echo
  echo "Pasos:"
  echo "  1. Ejecuta: git init"
  echo "  2. (Opcional) Comprueba con: ls -la .git"
  echo
  if [[ ! -d .git ]]; then
    read -r -p "¿Quieres que ejecute 'git init' por ti? (s/N): " auto
    if [[ "${auto,,}" == "s" || "${auto,,}" == "si" ]]; then
      git init
      mensaje_ok "Repositorio inicializado."
    fi
  else
    mensaje_info "Ya existe .git en este directorio."
  fi
  pausa
  ejecutar_verificacion 1
}

# Práctica de add/commit hasta 5 revisiones en el historial
ejercicio_2() {
  imprimir_cabecera "Ejercicio 2: Realizar 5 commits"
  echo "Objetivo: practicar git add y git commit hasta tener 5 commits."
  echo
  local n
  n=$(contar_commits)
  echo "Commits actuales: ${n} / 5"
  echo
  echo "Pasos sugeridos:"
  echo "  1. Crea o edita un archivo, por ejemplo:"
  echo "       echo '# Práctica Git' > README.md"
  echo "  2. Añade al staging:  git add README.md"
  echo "  3. Crea commit:       git commit -m \"mensaje descriptivo\""
  echo "  4. Repite con cambios distintos hasta llegar a 5 commits."
  echo
  echo "Ejemplos de mensajes:"
  echo "  - \"Añadir README inicial\""
  echo "  - \"Actualizar documentación\""
  echo "  - \"Corregir typo en README\""
  echo
  pausa
  ejecutar_verificacion 2
}

# git switch -c con nombres fijos para que el verificador sea determinista
ejercicio_3() {
  imprimir_cabecera "Ejercicio 3: Crear ramas"
  local def
  def=$(rama_por_defecto)
  echo "Objetivo: crear ramas y cambiar entre ellas."
  echo
  echo "Rama principal detectada: ${def}"
  echo
  echo "Pasos (usa estos nombres exactos para la verificación):"
  echo "  1. Asegúrate de estar en ${def}:"
  echo "       git switch ${def}"
  echo "  2. Crea la primera rama:"
  echo "       git switch -c feature/login"
  echo "  3. Vuelve a ${def} y crea la segunda:"
  echo "       git switch ${def}"
  echo "       git switch -c feature/docs"
  echo "  4. Vuelve a la rama principal:"
  echo "       git switch ${def}"
  echo
  pausa
  ejecutar_verificacion 3
}

# Merge de feature/login en la rama principal (requiere commit previo en la feature)
ejercicio_4() {
  imprimir_cabecera "Ejercicio 4: Fusionar ramas"
  local def
  def=$(rama_por_defecto)
  echo "Objetivo: integrar feature/login en ${def} con git merge."
  echo
  echo "Pasos:"
  echo "  1. Cambia a feature/login y haz al menos un commit único:"
  echo "       git switch feature/login"
  echo "       echo 'funcionalidad login' >> app.txt"
  echo "       git add app.txt && git commit -m \"Añadir módulo login\""
  echo "  2. Vuelve a ${def}:"
  echo "       git switch ${def}"
  echo "  3. Fusiona la rama:"
  echo "       git merge feature/login -m \"Merge branch feature/login\""
  echo
  pausa
  ejecutar_verificacion 4
}

# Crea dos commits que modifican la misma línea en ramas distintas → merge con conflicto
preparar_escenario_conflicto() {
  local def file
  def=$(rama_por_defecto)
  file="conflicto.txt"

  imprimir_cabecera "Preparación del escenario de conflicto"
  echo "Se creará un conflicto controlado entre ${def} y conflict-demo."
  echo

  read -r -p "¿Preparar el escenario automáticamente? (s/N): " prep
  [[ "${prep,,}" == "s" || "${prep,,}" == "si" ]] || return 0

  git switch "$def" 2>/dev/null || git checkout "$def"
  echo "linea original en main" > "$file"
  git add "$file"
  git commit -m "Base en ${def} para conflicto" 2>/dev/null || true

  git switch -c conflict-demo 2>/dev/null || git checkout -b conflict-demo
  echo "linea cambiada en conflict-demo" > "$file"
  git add "$file"
  git commit -m "Cambio en conflict-demo"

  git switch "$def" 2>/dev/null || git checkout "$def"
  echo "linea distinta en main" > "$file"
  git add "$file"
  git commit -m "Cambio distinto en ${def}"

  mensaje_info "Ahora ejecuta: git merge conflict-demo"
  mensaje_aviso "Se producirá un conflicto en ${file} — es lo esperado."
}

# Resolución manual de marcadores <<<<<<<; preparar_escenario_conflicto es opcional
ejercicio_5() {
  imprimir_cabecera "Ejercicio 5: Resolver conflictos"
  echo "Objetivo: resolver un merge con conflictos manualmente."
  echo
  echo "Pasos:"
  echo "  1. Provoca un merge con conflicto (puedes usar la preparación automática)"
  echo "  2. Abre el archivo en conflicto y elimina los marcadores <<<<<<< ======= >>>>>>>"
  echo "  3. Deja el contenido final deseado"
  echo "  4. Marca como resuelto: git add <archivo>"
  echo "  5. Completa el merge:   git commit -m \"Resolver conflicto de merge\""
  echo
  preparar_escenario_conflicto
  pausa
  ejecutar_verificacion 5
}

# origin + push -u; enlaza con la guía GitHub de la opción 0
ejercicio_6() {
  imprimir_cabecera "Ejercicio 6: Subir proyecto a GitHub"
  aviso_si_falta_config
  local def
  def=$(rama_por_defecto)
  cargar_preferencia_ssh
  if [[ -n "${HOST_SSH_GITHUB:-}" && "$HOST_SSH_GITHUB" != "github.com" ]]; then
    mensaje_info "Usas alias SSH '${HOST_SSH_GITHUB}' — remoto: git@${HOST_SSH_GITHUB}:USUARIO/REPO.git"
  elif ! listar_claves_publicas_ssh | grep -q .; then
    mensaje_aviso "Para push por SSH necesitas clave en ~/.ssh/ (opción 0 o ejercicio 9)."
  fi
  echo "Objetivo: conectar este repositorio con GitHub y subir los cambios."
  echo
  echo "Requisitos: cuenta en GitHub y acceso a red."
  echo
  echo "Pasos:"
  echo "  1. Crea un repositorio vacío en GitHub (sin README si ya tienes commits locales)"
  if command -v gh &>/dev/null; then
    echo "     O con GitHub CLI: gh repo create nombre-repo --public --source=. --remote=origin"
  fi
  echo "  2. Añade el remoto:"
  echo "       git remote add origin git@github.com:USUARIO/REPO.git"
  echo "     (o la URL HTTPS si prefieres)"
  echo "  3. Sube la rama y configura upstream:"
  echo "       git push -u origin ${def}"
  echo
  if git remote get-url origin &>/dev/null 2>&1; then
    mensaje_info "Remoto actual: $(git remote get-url origin)"
  fi
  pausa
  ejecutar_verificacion 6
}

# Bare repo y dos clones en el directorio PADRE de DIR_TRABAJO (no dentro del sandbox)
preparar_escenario_pareja() {
  local parent bare dev_a dev_b def
  parent="$(dirname "$DIR_TRABAJO")"
  bare="${parent}/pareja-repo.git"
  dev_a="${parent}/dev-a"
  dev_b="${parent}/dev-b"
  def=$(rama_por_defecto)

  imprimir_cabecera "Configuración del escenario en pareja"
  echo "Se usarán carpetas hermanas de tu directorio actual:"
  echo "  Bare (remoto simulado): ${bare}"
  echo "  Desarrollador A:        ${dev_a}"
  echo "  Desarrollador B:        ${dev_b}"
  echo

  read -r -p "¿Crear/actualizar el escenario automáticamente? (s/N): " prep
  [[ "${prep,,}" == "s" || "${prep,,}" == "si" ]] || return 0

  if [[ ! -d "$bare" ]]; then
    git init --bare "$bare"
    mensaje_ok "Repositorio bare creado."
  fi

  if [[ ! -d "$dev_a" ]]; then
    git clone "$bare" "$dev_a"
    mensaje_ok "Clon dev-a creado."
  fi
  if [[ ! -d "$dev_b" ]]; then
    git clone "$bare" "$dev_b"
    mensaje_ok "Clon dev-b creado."
  fi

  echo
  mensaje_info "Sigue estos pasos manualmente (simula dos personas):"
  echo
  echo "  PERSONA A (en ${dev_a}):"
  echo "    cd ${dev_a}"
  echo "    git remote add origin ${bare} 2>/dev/null || git remote set-url origin ${bare}"
  echo "    echo 'cambio de A' >> trabajo.txt && git add . && git commit -m 'dev-a: primer commit'"
  echo "    git push -u origin ${def}"
  echo
  echo "  PERSONA B (en ${dev_b}):"
  echo "    cd ${dev_b}"
  echo "    git pull origin ${def}"
  echo "    echo 'cambio de B' >> trabajo.txt && git add . && git commit -m 'dev-b: segundo commit'"
  echo "    git push origin ${def}"
  echo
  echo "  PERSONA A de nuevo:"
  echo "    cd ${dev_a} && git pull origin ${def}"
  echo
}

# Push/pull entre dev-a y dev-b vía bare (simula dos personas)
ejercicio_7() {
  imprimir_cabecera "Ejercicio 7: Trabajar en parejas"
  echo "Objetivo: simular flujo de dos desarrolladores con push/pull."
  echo
  echo "Un solo directorio no basta para dos personas; usamos un bare + dos clones."
  echo
  preparar_escenario_pareja
  pausa
  ejecutar_verificacion 7
}

# *.log, .env, node_modules/ y archivo prueba.log no trackeado
ejercicio_8() {
  imprimir_cabecera "Ejercicio 8: Usar .gitignore"
  echo "Objetivo: evitar que archivos locales entren al repositorio."
  echo
  echo "Pasos:"
  echo "  1. Crea .gitignore con al menos estas líneas:"
  echo "       *.log"
  echo "       .env"
  echo "       node_modules/"
  echo "  2. Crea un archivo de prueba:"
  echo "       echo 'log de prueba' > prueba.log"
  echo "  3. Comprueba que Git lo ignora:"
  echo "       git status"
  echo "       git check-ignore -v prueba.log"
  echo
  if [[ -f .gitignore ]]; then
    mensaje_info "Ya existe .gitignore en este directorio."
  fi
  pausa
  ejecutar_verificacion 8
}

# Reutiliza configurar_ssh_github; verificación exige ssh -T exitoso con GitHub
ejercicio_9() {
  imprimir_cabecera "Ejercicio 9: Configurar SSH con GitHub"
  aviso_si_falta_config
  echo "Objetivo: cliente OpenSSH, clave en ~/.ssh/ de $(whoami) y autenticación con GitHub."
  echo
  echo "Si hay varias claves o cuentas GitHub, usa la opción 0 o este ejercicio para"
  echo "elegir clave y alias Host (~/.ssh/config)."
  echo
  configurar_ssh_github
  pausa
  ejecutar_verificacion 9
}

# Integración: feature/release-prep, merge --no-ff, tag v1.0.0, historial largo
ejercicio_10() {
  imprimir_cabecera "Ejercicio 10: Simular flujo profesional completo"
  local def
  def=$(rama_por_defecto)
  echo "Objetivo: integrar ramas, merge --no-ff, tags y opcionalmente push."
  echo
  echo "Checklist:"
  echo "  1. Crea rama de feature:"
  echo "       git switch -c feature/release-prep"
  echo "  2. Haz al menos un commit en esa rama:"
  echo "       echo 'preparar release' >> CHANGELOG.md"
  echo "       git add CHANGELOG.md && git commit -m \"Preparar release v1.0.0\""
  echo "  3. Vuelve a ${def} y fusiona sin fast-forward:"
  echo "       git switch ${def}"
  echo "       git merge --no-ff feature/release-prep -m \"Release v1.0.0\""
  echo "  4. Crea tag anotado:"
  echo "       git tag -a v1.0.0 -m \"Primera release estable\""
  echo "  5. (Opcional) Sube al remoto:"
  echo "       git push origin ${def} --tags"
  echo
  echo "Commits actuales: $(contar_commits) (se requieren ≥ 8 al verificar)"
  echo
  pausa
  ejecutar_verificacion 10
}

# ═══════════════════════════════════════════════════════════════
# MENÚ, DOCUMENTACIÓN Y OPCIÓN 0
# ═══════════════════════════════════════════════════════════════

# Muestra README junto al script o en DIR_TRABAJO; opcionalmente abre less
ver_readme() {
  local readme="$ARCHIVO_README"
  if [[ ! -f "$readme" && -f "${DIR_TRABAJO}/README.md" ]]; then
    readme="${DIR_TRABAJO}/README.md"
  fi

  imprimir_cabecera "Documentación — README"
  if [[ ! -f "$readme" ]]; then
    mensaje_aviso "No se encontró README.md."
    echo "  Buscado en: ${ARCHIVO_README}"
    echo "            y ${DIR_TRABAJO}/README.md"
    pausa
    return 0
  fi

  mensaje_info "Archivo: ${readme}"
  echo
  echo "  También puedes abrirlo fuera del programa:"
  echo "    less ${readme}"
  if command -v xdg-open &>/dev/null; then
    echo "    xdg-open ${readme}"
  fi
  echo
  read -r -p "¿Mostrar el README aquí? (s/N): " mostrar
  if [[ "${mostrar,,}" == "s" || "${mostrar,,}" == "si" ]]; then
    echo
    if command -v less &>/dev/null; then
      less -R "$readme"
    else
      cat "$readme"
      echo
      pausa
    fi
  fi
}

# Pinta el menú principal y el indicador de progreso [0✓]…[10 ]
mostrar_menu() {
  clear 2>/dev/null || true
  imprimir_cabecera "${NOMBRE_PROGRAMA} — Práctica Git (básico → avanzado)"
  mensaje_info "Directorio: ${DIR_TRABAJO}"
  echo -n "Progreso: "
  indicador_progreso
  echo
  echo "  0. Configurar Git en Ubuntu y enlazar con GitHub"
  echo "  1. Crear repositorio local"
  echo "  2. Realizar 5 commits"
  echo "  3. Crear ramas"
  echo "  4. Fusionar ramas"
  echo "  5. Resolver conflictos"
  echo "  6. Subir proyecto a GitHub"
  echo "  7. Trabajar en parejas"
  echo "  8. Usar .gitignore"
  echo "  9. Configurar SSH"
  echo " 10. Simular flujo profesional completo"
  echo
  echo "  r. Ver README.md (documentación)"
  if [[ -f "$ARCHIVO_README" ]]; then
    echo "     ${ARCHIVO_README}"
  elif [[ -f "${DIR_TRABAJO}/README.md" ]]; then
    echo "     ${DIR_TRABAJO}/README.md"
  fi
  echo "  (q / salir para terminar)"
  echo
  if ! ejercicio_completado 0; then
    mensaje_aviso "Empieza por la opción 0 si aún no tienes Git instalado o configurado."
  elif ! ejercicio_completado 1; then
    mensaje_aviso "Se recomienda seguir el orden 0→10: cada ejercicio construye sobre el anterior."
  fi
}

# Tutorial pasos A–E: cuenta GitHub, SSH keys, nuevo repo, remote y push
guia_configurar_cuenta_github() {
  imprimir_cabecera "Configurar tu cuenta de GitHub (para trabajar con Git local)"
  local nombre_git email_git
  nombre_git=$(git config --global --get user.name 2>/dev/null || true)
  email_git=$(git config --global --get user.email 2>/dev/null || true)

  echo "Git local (lo que configuró esta opción 0) y GitHub son cosas distintas"
  echo "que debes unir: Git guarda commits en tu PC; GitHub aloja copia remota y colaboración."
  echo
  if [[ -n "$nombre_git" ]]; then
    mensaje_info "Identidad Git local actual: ${nombre_git} <${email_git:-sin email}>"
  else
    mensaje_aviso "Aún no has definido user.name / user.email en Git (completa el paso anterior)."
  fi
  echo
  echo "── Paso A: Cuenta en GitHub ──"
  echo "  1. Abre https://github.com/signup y crea la cuenta (o inicia sesión)."
  echo "  2. Elige tu nombre de usuario (aparece en las URLs: github.com/USUARIO)."
  echo "  3. Verifica el correo: icono perfil → Settings → Emails → verifica el email."
  echo "     Usa el mismo email que en 'git config user.email' si es posible."
  echo
  echo "── Paso B: Perfil y commits ──"
  echo "  4. Settings → Profile: puedes poner el mismo nombre que user.name de Git."
  echo "  5. Settings → Emails:"
  echo "     - Marca el email que usarás en los commits."
  echo "     - Opcional: activa 'Keep my email addresses private' y usa el email"
  echo "       noreply de GitHub en: git config --global user.email \"ID+USUARIO@users.noreply.github.com\""
  echo
  echo "── Paso C: Autenticación SSH (recomendada con git@github.com) ──"
  echo "  6. En tu PC (usuario Linux $(whoami)) ya debes tener una clave en ~/.ssh/"
  echo "     (la opción 0 anterior ayuda a generarla o elegirla)."
  echo "  7. En GitHub: Settings → SSH and GPG keys → New SSH key"
  echo "     - Title: por ejemplo \"Portátil $(hostname -s 2>/dev/null || echo casa)\""
  echo "     - Key: pega el contenido de tu .pub, por ejemplo:"
  echo "         cat ~/.ssh/id_ed25519_github_$(whoami).pub"
  echo "       (o la ruta que hayas elegido en git-BUH)"
  echo "     - Add SSH key"
  echo "  8. Comprueba desde la terminal:"
  echo "         ssh -T git@github.com"
  echo "     Debe responder con 'Hi TU_USUARIO_GITHUB! ...' (código de salida 1 es normal)."
  echo
  echo "── Paso D: Crear un repositorio en GitHub ──"
  echo "  9. Pulsa '+' arriba → New repository"
  echo " 10. Nombre del repo (ej. practica-git). Público o privado."
  echo " 11. NO marques 'Add a README' si ya tienes commits locales (ejercicio 1+)."
  echo " 12. Create repository. Copia la URL que te muestra GitHub."
  echo
  echo "── Paso E: Unir el repo local de Git con GitHub ──"
  echo " 13. En la carpeta donde practicas con git-BUH (con .git/):"
  echo "         git remote add origin git@github.com:TU_USUARIO/NOMBRE_REPO.git"
  echo "       (sustituye TU_USUARIO y NOMBRE_REPO; si usas alias SSH en ~/.ssh/config,"
  echo "        la URL será git@TU_ALIAS:TU_USUARIO/NOMBRE_REPO.git)"
  echo " 14. Sube tu rama principal:"
  echo "         git push -u origin main"
  echo "       (o 'master' si esa es tu rama — el ejercicio 6 del menú lo practica)"
  echo
  echo "── Alternativa: HTTPS en lugar de SSH ──"
  echo "  • Remoto: https://github.com/TU_USUARIO/NOMBRE_REPO.git"
  echo "  • Settings → Developer settings → Personal access tokens → Generate new token"
  echo "  • Al hacer git push, usuario = tu usuario GitHub, contraseña = el token"
  echo "  • No subas el token al repositorio ni lo guardes en este script"
  echo
  echo "── Resumen: qué hace cada parte ──"
  echo "  | En tu PC (Git)              | En GitHub                          |"
  echo "  |-----------------------------|-------------------------------------|"
  echo "  | git config user.name/email  | Cuenta, email verificado, perfil   |"
  echo "  | ~/.ssh/clave + ssh -T       | Settings → SSH keys (clave .pub)   |"
  echo "  | git init, commits locales   | New repository (vacío al principio)|"
  echo "  | git remote add origin …     | URL del repo en la página del repo   |"
  echo "  | git push -u origin main     | Código visible en la web de GitHub |"
  echo
}

# Invoca la guía larga y añade diagrama/resumen SSH vs HTTPS
guia_github_enlace() {
  guia_configurar_cuenta_github
  echo
  imprimir_cabecera "Referencia rápida: Git local ↔ GitHub"
  echo "1. Cuenta y perfil en GitHub"
  echo "   Guía detallada arriba (pasos A–E). Alta: https://github.com/signup"
  echo
  echo "2. Misma identidad en Git y GitHub"
  echo "   El email de 'git config user.email' debe coincidir con tu cuenta GitHub"
  echo "   (o el email privado/noreply de commits en GitHub → Settings → Emails)."
  echo
  echo "3. Cómo se conectan Git local y GitHub"
  echo "   ┌─────────────────┐     git remote add origin <url>     ┌──────────────────┐"
  echo "   │  Tu PC (.git)   │ ──────────────────────────────────► │  Repo en GitHub  │"
  echo "   │  commits locales│     git push / git pull             │  historial remoto│"
  echo "   └─────────────────┘                                     └──────────────────┘"
  echo
  echo "4. Dos formas de autenticarte al subir código"
  echo "   SSH (recomendado para git@github.com:…):"
  echo "     - Instala openssh-client (la opción 0 puede hacerlo en Ubuntu)"
  echo "     - Clave en ~/.ssh/ del usuario Linux actual (puede haber varias)"
  echo "     - Regístrala en: https://github.com/settings/keys"
  echo "     - Varios usuarios Linux → cada uno su ~/.ssh/"
  echo "     - Varias cuentas GitHub → varias claves + alias en ~/.ssh/config"
  echo "     - URL: git@github.com:USUARIO/REPO.git (o git@ALIAS:… si usas Host)"
  echo "     - Detalle: opción 0 y ejercicio 9"
  echo
  echo "   HTTPS:"
  echo "     - URL remota: https://github.com/USUARIO/REPO.git"
  echo "     - Usa un Personal Access Token como contraseña al hacer push"
  echo "     - No guardes el token en este script ni en archivos del repo"
  echo
  echo "5. Comandos útiles para comprobar la conexión"
  echo "   git config --global -l"
  echo "   ls -la ~/.ssh/*.pub     (claves de este usuario)"
  echo "   ssh -T git@github.com   (o ssh -T git@TU_ALIAS si usas config)"
  echo "   git remote -v           (tras crear un repo y añadir origin, ejercicio 6)"
  echo
  cargar_preferencia_ssh
  if [[ -n "${CLAVE_SSH_PRIVADA:-}" && -f "${CLAVE_SSH_PRIVADA}" ]]; then
    mensaje_info "Preferencia git-BUH: clave ${CLAVE_SSH_PRIVADA}, host ${HOST_SSH_GITHUB}"
  fi
}

# Opción 0 completada si hay git + identidad global (no exige SSH ni push aún)
verificar_configuracion_inicial() {
  local errores=()
  if ! command -v git &>/dev/null; then
    errores+=("Git no está instalado o no está en el PATH")
  fi
  if ! tiene_identidad_git; then
    errores+=("Faltan user.name o user.email globales (git config --global)")
  fi
  if [[ ${#errores[@]} -eq 0 ]]; then
    marcar_ejercicio_completado 0
    mensaje_ok "Configuración inicial completada."
    return 0
  fi
  mensaje_error "Configuración incompleta:"
  printf ' - %s\n' "${errores[@]}"
  return 1
}

# Opción 0 del menú: apt (git, openssh), identidad, SSH, guías GitHub
configurar_git_ubuntu() {
  imprimir_cabecera "${NOMBRE_PROGRAMA} — Configurar Git en Ubuntu y enlazar con GitHub"
  echo "Objetivo: instalar Git, definir tu identidad local y entender cómo enlazar con GitHub."
  echo

  if es_ubuntu_o_debian; then
    mensaje_info "Sistema detectado: Ubuntu/Debian."
  else
    mensaje_aviso "No se detectó Ubuntu/Debian. Los pasos con apt no se ejecutarán automáticamente."
    echo "Instala Git manualmente según tu distribución."
    echo
  fi

  if ! command -v git &>/dev/null; then
    mensaje_aviso "Git no está instalado."
    if es_ubuntu_o_debian; then
      echo "Comandos para Ubuntu/Debian:"
      echo "  sudo apt-get update"
      echo "  sudo apt-get install -y git"
      echo
      read -r -p "¿Ejecutar instalación con apt ahora? (s/N): " instalar
      if [[ "${instalar,,}" == "s" || "${instalar,,}" == "si" ]]; then
        if sudo apt-get update && sudo apt-get install -y git; then
          mensaje_ok "Git instalado correctamente."
        else
          mensaje_error "Falló la instalación. Comprueba permisos sudo o instala manualmente."
          echo "Documentación: https://git-scm.com/download/linux"
        fi
      fi
    else
      echo "Visita: https://git-scm.com/download/linux"
    fi
  else
    mensaje_ok "Git ya está instalado: $(git --version)"
  fi

  if ! command -v git &>/dev/null; then
    mensaje_aviso "Instala Git antes de configurar user.name y user.email."
    guia_github_enlace
    pausa
    verificar_configuracion_inicial || true
    return
  fi

  echo
  imprimir_cabecera "Identidad local (obligatoria para commits)"
  local nombre_actual email_actual nombre email
  nombre_actual=$(git config --global --get user.name 2>/dev/null || true)
  email_actual=$(git config --global --get user.email 2>/dev/null || true)
  [[ -n "$nombre_actual" ]] && echo "Nombre actual: ${nombre_actual}"
  [[ -n "$email_actual" ]] && echo "Email actual:  ${email_actual}"
  echo

  read -r -p "Nombre para git config user.name: " nombre
  read -r -p "Email para git config user.email: " email
  if [[ -z "$nombre" || -z "$email" ]]; then
    mensaje_aviso "Nombre y email son obligatorios para marcar la configuración como completa."
  else
    git config --global user.name "$nombre"
    git config --global user.email "$email"
    mensaje_ok "Identidad configurada: ${nombre} <${email}>"
  fi

  echo
  read -r -p "¿Aplicar valores recomendados (rama main, colores, pull.rebase)? (s/N): " extra
  if [[ "${extra,,}" == "s" || "${extra,,}" == "si" ]]; then
    git config --global init.defaultBranch main
    git config --global color.ui auto
    git config --global pull.rebase false
    mensaje_ok "Valores recomendados aplicados."
  fi

  echo
  configurar_ssh_github
  echo
  guia_github_enlace
  pausa
  verificar_configuracion_inicial || true
  if ! listar_claves_publicas_ssh | grep -q .; then
    mensaje_aviso "Aún no hay claves SSH en ~/.ssh/ de $(whoami). Complétalas antes del ejercicio 6 (push por SSH) o 9."
  fi
}

# Punto de entrada: aviso de carpeta, bucle de menú (0–10, r, q)
principal() {
  migrar_progreso_antiguo
  aviso_directorio_trabajo

  while true; do
    mostrar_menu
    read -r -p "Elige una opción (0-10, r=README, q=salir): " eleccion
    case "$eleccion" in
      q|Q|salir) mensaje_info "¡Hasta luego!"; exit 0 ;;
      r|R|readme|README) ver_readme ;;
      0) configurar_git_ubuntu ;;   # No exige git previo (puede instalarlo aquí)
      1) requerir_git && ejercicio_1 || true ;;
      2) requerir_git && ejercicio_2 || true ;;
      3) requerir_git && ejercicio_3 || true ;;
      4) requerir_git && ejercicio_4 || true ;;
      5) requerir_git && ejercicio_5 || true ;;
      6) requerir_git && ejercicio_6 || true ;;
      7) requerir_git && ejercicio_7 || true ;;
      8) requerir_git && ejercicio_8 || true ;;
      9) requerir_git && ejercicio_9 || true ;;
      10) requerir_git && ejercicio_10 || true ;;
      *) mensaje_aviso "Opción no válida. Usa 0-10, r (README) o q para salir." ;;
    esac
  done
}

# Invocación directa del script (no se usa si se hace source del archivo)
principal "$@"
