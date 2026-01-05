# Algunas configuraciones en `radare2`

Para configurar el entorno de `radare2` podemos usar distintas variables.

Por ejemplo, podemos poner el tema solarizado:

```
[0x0000fff0]> eco solarized
```

O activar UTF-8:

```
[0x0000fff0]> e scr.utf8 = true
```

Una de las variables más importantes que vamos a usar con `r2` es determinar el número de bits del binario en análisis:

```
[0x0000fff0]> e asm.bits = 16
[0000:fff0]>
```
