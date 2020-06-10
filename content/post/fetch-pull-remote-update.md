+++
author = "Let Bulochkin"
title = "Git: разница между fetch, pull и remote update"
date = "2020-05-12"
description = "Guide to emoji usage in Hugo"
tags = [
    "git",
]
+++

На практике оказалось очень важным понимать суть `git pull` и отличие от `git fetch` и `git remote update`.
<!--more-->
Для понимания работы `git remote update` важно иметь представление о ссылках в Git. Ссылка - это некоторый текстовый указатель на коммит с определенным хэшем. По сути ссылка подменяет сложный в прочтении хэш. Более того, все имена веток на самом деле представляют собой ссылки на последний коммит в этой ветке. Ссылка реализована в виде файла, который содержит хэш коммита, на который она указывает. Сами файлы лежат в подкаталоге .git/refs/:
```
$ ls .git/refs/
heads  remotes  tags
$ ls .git/refs/heads/  # локальные ветки репозитория
somebranch  master
$ cat .git/refs/heads/master 
2c3d6d2317874f7e3a433751f5487cbf81f83030  # хэш последнего коммита в ветке master
```

Ссылки можно создавать вручную. Особая ссылка - HEAD. Она всегда указывает на последний коммит в текущей рабочей ветке:
```
$ cat .git/HEAD
ref: refs/heads/somebranch  # если мы в ветке somebranch
```

Для удобства работы с удаленными репозиториями в Git существуют т.н. ссылки на отслеживаемые ветки. Ссылка на отслеживаемую ветку - это ссылка на локальный коммит, скачанный когда-то с удаленного репозитория и соответствующий удаленной ветке на момент скачивания. Ссылка на отслеживаемую ветку имеет вид `origin/master`, где вместо `origin` будет псевдоним удаленного репозитория, а вместо `master` - название скачанной ветки. Хорошо на примере объяснено здесь: https://git-scm.com/book/ru/v2/%D0%92%D0%B5%D1%82%D0%B2%D0%BB%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B2-Git-%D0%A3%D0%B4%D0%B0%D0%BB%D1%91%D0%BD%D0%BD%D1%8B%D0%B5-%D0%B2%D0%B5%D1%82%D0%BA%D0%B8

Здесь в русскоязычной документации есть путаница, где схожие понятия переводятся одинаково. Локальная ветка, скачанная с удаленного репозитория, автоматически настраивается на отслеживание оригинальной ветки (tracking branch -> upstream branch). Это означает, что такие команды, как `git fetch` и `git pull`, вызванные в этой ветке, будут автоматически обработаны для нужной upstream branch. Локальную ветку по удаленной можно создать командой `git checkout --track origin/somebranch`.

`git fetch` стягивает коммиты удаленной ветки и обновляет локальную ветку начиная с предыдущей ссылки на отслеживаемую ветку:
![git_fetch](https://git-scm.com/book/en/v2/images/remote-branches-3.png "git fetch")

`git remote update` сделает это действие со всеми локальными ветками в репозитории. Если не выставлены специфичные настройки, то команда равнозначна `git fetch --all`.

`git pull` не только стянет новые коммиты с удаленного репозитория, но и произведет их слияние в указанную ветку. `git pull remote HEAD` выполнит слияние ветки origin/HEAD с текущей локальной веткой. 

Материалы для прочтения:
* https://git-scm.com/book/ru/v2/Git-%D0%B8%D0%B7%D0%BD%D1%83%D1%82%D1%80%D0%B8-%D0%A1%D1%81%D1%8B%D0%BB%D0%BA%D0%B8-%D0%B2-Git
* https://stackoverflow.com/questions/17712468/what-is-the-difference-between-git-remote-update-git-fetch-and-git-pull/17712553 
* https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches