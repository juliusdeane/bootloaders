#!/bin/sh

echo " ######:   ########  ##         ######     :####:  ######:    .####."
echo " #######:  ########  ##         ######     ######  #######    ######"
echo " ##   :##  ##        ##           ##     :##:  .#  ##   :##  :##  ##:"
echo " ##    ##  ##        ##           ##     ##:       ##    ##  ##:  :##"
echo " ##   :##  ##        ##           ##     ##.       ##   :##  ##    ##"
echo " #######:  #######   ##           ##     ##        #######:  ##    ##"
echo " ######:   #######   ##           ##     ##  ####  ######    ##    ##"
echo " ##        ##        ##           ##     ##. ####  ##   ##.  ##    ##"
echo " ##        ##        ##           ##     ##:   ##  ##   ##   ##:  :##"
echo " ##        ##        ##           ##     :##:  ##  ##   :##  :##  ##:"
echo " ##        ########  ########   ######    #######  ##    ##:  ######"
echo " ##        ########  ########   ######     :####.  ##    ###  .####."

echo
echo "[PELIGRO] Esto va a generar MUCHÍSIMA TRAZA: puede que incluso colapse QEMU y no lo veas avanzar!"
echo "¿Estás seguro de que quieres lanzarlo con -d all?"
echo
while :
do
  echo "Pulsa S si quieres continuar o N si quieres cancelar (N/S):"
  read respuesta

  # Todo mayúsculas.
  respuesta_cap=$(echo "$respuesta" | tr "[:lower:]" "[:upper:]")
  case "$respuesta_cap" in
    S)
        echo "[PELIGRO] Has elegido Sí. ¡Continuando!"
        qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -no-reboot -monitor file:ch6_output.log -d all -D ch6_detallado.log
        break
        ;;
    N)
        echo "'Has elegido sabiamente'. Saliendo..."
        exit 0 # Termina el script
        ;;
    *)
        echo "[!!] Opción no válida. Por favor, introduce S o N."
        ;;
    esac
done
