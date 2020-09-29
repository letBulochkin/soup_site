+++
author = "Letchik Bulochkin"
title = "tmux: настройка для использования системного буфера обмена"
date = "2020-09-29"
description = ""
tags = [
    "tmux", "tools", "Linux"
] 
+++

Tmux (от terminal multiplexor) удобен тем, что позволяет не только создавать несколько терминальных сессий в одном окне, но и управлять ими с помощью гибко настраиваемых сочетаний клавиш. tmux также по умолчанию предоставляет сочетания клавиш для работы с текстом двух видов - в стиле Emacs и в стиле vi, что полезно, если вы часто работаете с одним из этих редакторов.

Есть, впрочем, один существенный на мой взгляд недостаток. tmux работает с собственными буферами обмена, то есть все, что вы копируете из tmux, остается там же. Для исправления этой ситуации необходимо немного отредактировать конфиг tmux.

Что я хотел достичь:

* Операции выделения, копирования и вставки по сочетаниям клавиш, аналогичным в Vim (**v**, **y** и **p** соответственно).
* Автоматическое копирование выделенного мышью фрагмента.
* Копирование в системный буфер обмена. 

<!--more-->

Пользовательские настройки tmux прописываются в конфиге `~/.tmux.conf`. Для решения поставленной задачи я привел свой конфиг к следующему виду:
```
set-window-option -g mode-keys vi
set -g mouse on
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe 'xclip -in -selection clipboard'
```

Также необходимо установить xclip.

В tmux существует два режима сочетаний клавиш для работы с текстом, выделением, копированием и вставкой. Режим `copy-mode` предоставляет сочетания клавиш "в стиле" Emacs, режим `copy-mode-vi` - в стиле vi. По умолчанию по нажатию сочетания клавиш **C-b [** актвируется режим `copy-mode`. Посмотреть доступные сочетания клавиш для каждого из режимов можно или введя в терминале команду `tmux list-keys -T <режим>`, или, если tmux уже запущен, перейти в командный режим нажатием **C-b :** и ввести ту же команду: `list-keys -T <режим>`. Пример:
```
$ tmux list-keys -T copy-mode
bind-key -T copy-mode C-Space           send-keys -X begin-selection
bind-key -T copy-mode C-a               send-keys -X start-of-line
bind-key -T copy-mode C-b               send-keys -X cursor-left
bind-key -T copy-mode C-c               send-keys -X cancel
bind-key -T copy-mode C-e               send-keys -X end-of-line
bind-key -T copy-mode C-f               send-keys -X cursor-right
bind-key -T copy-mode C-g               send-keys -X clear-selection
bind-key -T copy-mode C-k               send-keys -X copy-end-of-line
bind-key -T copy-mode C-n               send-keys -X cursor-down
bind-key -T copy-mode C-p               send-keys -X cursor-up
```

Командой `set-window-option -g mode-keys vi` устанавливается, что по нажатию сочетания **C-b [** будет активирован режим копирования vi.

Командой `set -g mouse on` разрешается выделение текста мышью. По умолчанию текст копируется во внутренний буфер tmux.

Команды `bind-key -T copy-mode-vi <key> send-keys -X <operation>` устанавливается бинд для выполнения операций выделения:

* `begin-selection` - начало выделения;
* `rectangle-toggle` - выделение произвольной прямоугольной области вместо выделения по строкам (аналог Visual Block режима в vi)
* постфикс `-and-cancel` к любой из этих операций еще и завершит режим копирования.

Команды `bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'` и `bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe 'xclip -in -selection clipboard'` создают бинд на два события соответственно: нажатие клавиши **y** и  отпускание ЛКМ (`MouseDragEnd1Pane`). Каждое из событий связывается с операцией `copy-pipe`, которая работает аналогично операции `copy-selection` - копирует выделенный фрагмент текста в буфер tmux, но еще и отправляет его на стандратный ввод команде, прописанной в следующем аргументе.

В нашем случае скопированный фрагмент подается на ввод xclip с параметрами `-in` - обработать данные из stdin, и `-selection clipboard` - использовать буфер обмена `CLIPBOARD` вместо `PRIMARY` (используется для хранения текста, выделенного мышью, и вставки по нажатию колесика) или `SECONDARY` (может использоваться для различных целей).

Применить изменения кофингурации можно или убив tmux-сервер командой `tmux kill-server` и запустив его заново, или выполнить команду `source-file <PATH>`.

Материалы для чтения:

* https://sanctum.geek.nz/arabesque/vi-mode-in-tmux/
* https://unix.stackexchange.com/questions/348913/copy-selection-to-a-clipboard-in-tmux
* https://www.rushiagr.com/blog/2016/06/16/everything-you-need-to-know-about-tmux-copy-pasting/
* https://www.freecodecamp.org/news/tmux-in-practice-integration-with-system-clipboard-bcd72c62ff7b/
* https://til.hashrocket.com/posts/d4d3c1fea6-quickly-edit-and-reload-tmux-configuration
