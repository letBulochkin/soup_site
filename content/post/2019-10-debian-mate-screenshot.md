+++
author = "Letchik Bulochkin"
title = "Установка сочетания клавиш для скриншота в Debian 10 + Mate"
date = "2019-10-01"
description = "Установка сочетания клавиш для скриншота в Debian 10 + Mate"
tags = [
    "Debian",
    "GNOME",
    "Mate",
    "Linux"
]
+++

**Задача:** по нажатию клавиши PrintScreen получать снимок экрана выбранной области. Что может быть проще. Набор: **Debian 10 Buster + Mate 1.20.4**.

Стоит сказать, что до этого для решения этой задачи я как идиот каждый раз открывал терминал и вбивал туда `scrot -s`. Это не удобно, поэтому прикрутить кейбинд на эту команду я хотел давно.

<!--more-->

Большая часть советов в глобальной сети Интернет на этот счет подсказывает следующее: пойди в графический интерфейс и сделай то-то.

![Mate_keyboard](https://sun9-45.userapi.com/c857124/v857124855/7b8/LtCvpWfw7cA.jpg "Интерфейс добавления сочетаний клавиш Mate")
<div style="text-align: center;"><i>Все было бы хорошо, если было бы хорошо</i></div>


Для того, чтобы передать команде параметр, всю исполняемую команду необходимо обернуть в кавычки. 

Но этот способ упорно не работал, выдавая ошибку. 

Так как Mate - это форк GNOME 2, то под капотом Mate используются утилиты GNOME. Например, `gsettings`. Эта утилита представляет все настройки графического окружения в виде групп **схема-ключ-значение**. Если выполнить `gsettings list-schemas`, то появится бесконечный список схем, группирующих различные параметры графического окружения. Сузим поиск и найдем те схемы, которые относятся к клавишам: `gsettings list-schemas | grep key`. Получим:
```
org.mate.SettingsDaemon.plugins.keyboard
org.mate.peripherals-keyboard-xkb.preview
org.mate.peripherals-keyboard-xkb.kbd
org.mate.peripherals-keyboard
org.mate.Marco.keybinding-commands
org.mate.SettingsDaemon.plugins.media-keys
org.mate.Marco.window-keybindings
org.mate.accessibility-keyboard
org.mate.SettingsDaemon.plugins.keybindings
org.mate.peripherals-keyboard-xkb
org.mate.peripherals-keyboard-xkb.indicator
org.mate.Marco.global-keybindings
org.mate.terminal.keybindings
org.gnome.desktop.wm.keybindings
org.gnome.desktop.peripherals.keyboard
org.mate.peripherals-keyboard-xkb.general
org.mate.SettingsDaemon.plugins.a11y-keyboard
org.gnome.desktop.a11y.keyboard
```

Командой `gsettings list-keys` посмотрим, какие ключи принадлежат этим схемам.

Опытным путем выяснилось следующее. В схеме `org.mate.Marco.keybinding-commands` содержатся ключи, отвечающие за пользовательские команды (в том числе взятия снимка экрана и снимка активного окна). Значением каждого ключа является команда, которую пользователь хочет выполнять по нажатию сочетания клавиш. В схеме `org.mate.Marco.global-keybindings` содержатся ключи (в том числе и для пользовательских команд, например `run-command-2`, значениями которых являются сочетания клавиш, по нажатию которых будет выполняться команда.

Во время этого же поиска я наткнулся на использование встроенной в Mate утилиты `mate-screenshot`, которая при вызове с параметром `-a` делает ровно то, что мне нужно - предлагает выделить область и берет снимок именно этой области. Более того, вызов утилиты `mate-scrrenshot --area --interactive` был уже забит на сочетания Shift+PrtScr. Окей, клево, но мне не нравится сочетание, и не нравится появление диалогового окна каждый раз, прежде чем я хочу просто взять скриншот (за это отвечает опция `--interactive`). Ок, `scrot` больше не нужен, забьем новое сочетание как хотим:
```
gsettings set org.mate.Marco.keybinding-commands command-2 'mate-screenshot --area'
gsettings set org.mate.Marco.global-keybindings run-command-2 'Print'
```
Но не тут-то было. По нажатию PrtScr ничего не происходило.

Более того, не выполнялась вообще ни одна команда, не вызывавшая графический интерфейс. `mate-screenshot --area --interactive` - пожалуйста. `mate-screenshot --area` - нет, увольте. Вызвать `emacs` - да запросто. Выполнить `nano` - ноуп.

Спасибо друзьям, которые подсказали, что по этому поводу в репозитории Mate [есть целая ишшуя](https://github.com/mate-desktop/mate-utils/issues/37), в комментах к которой и нашлось решение. 

Если кратко: проблема в тайминге. 

В директории `/usr/local/bin` создается shell-скрипт **mate-screenshot** следующего содержания:
```bash
#!/bin/bash

sleep 1
exec /usr/bin/mate-screenshot $@
```
Теперь меняем наш бинд на следующий:
```
gsettings set org.mate.Marco.keybinding-commands command-2 '/usr/local/bin/mate-screenshot --area'
gsettings set org.mate.Marco.global-keybindings run-command-2 'Print'
```
Теперь все работает.