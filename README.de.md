# iRotar

[中文](README.md) | [English](README.en.md) | [Deutsch](README.de.md)

Der Bildschirm eines MacBook Pro kann mit dem integrierten Bewegungssensor automatisch gedreht werden.

## Einfuehrung

**iRotar for Mac** ist ein Dienstprogramm fuer macOS, mit dem sich der Bildschirm eines Apple-Notebooks bequem drehen laesst. Die Drehung kann ueber das Systemmenue, ueber globale Tastenkombinationen oder automatisch durch das Notebook selbst erfolgen. Zusaetzlich kann die Richtung des integrierten Trackpads zusammen mit dem Bildschirm angepasst werden. Moeglich wird das durch den in Apple-Notebooks eingebauten Bewegungssensor.

## Einschraenkungen

Derzeit werden nur 64-Bit-Versionen von macOS unterstuetzt. Bei manueller Drehung versucht das Programm, den Bildschirm zu drehen, auf dem sich der Mauszeiger gerade befindet. Dieses Verhalten ist jedoch noch nicht vollstaendig getestet.

## Hinweise

Die Achsenausrichtung des Sensors unterscheidet sich je nach Notebook-Modell. Im automatischen Drehmodus kann iRotar den Bildschirm auf manchen Geraeten daher genau in die entgegengesetzte Richtung drehen. Falls das passiert, aktiviere im Menue die Option "Swap Sensor Axes".

![screenshot-01](images/screenshot-01.png)

## Referenzen: Tastenkombinationen anpassen

http://apple.stackexchange.com/questions/16135/remap-home-and-end-to-beginning-and-end-of-line
http://superuser.com/questions/257199/arbitrary-key-remapping-on-a-mac
https://discussions.apple.com/thread/1924733?start=0&tstart=0

## Referenzen: Sudden Motion Sensor Access Library

```
Copyright (c) 2010 Suitable Systems
All rights reserved.

Developed by: Daniel Griscom
              Suitable Systems
              http://www.suitable.com

For more information about SMSLib, see
     <http://www.suitable.com/tools/smslib.html>
or contact
     Daniel Griscom
     Suitable Systems
     1 Centre Street, Suite 204
     Wakefield, MA 01880
     (781) 665-0053
```
