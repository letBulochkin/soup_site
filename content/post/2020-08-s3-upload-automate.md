+++
author = "Let Bulochkin"
title = "Автоматизация выгрузки статического сайта в бакет S3"
date = "2020-08-13"
description = "Автоматизация выгрузки статического сайта в бакет S3"
tags = [
    "bash", "AWS", "S3", "scripting", "this site"
] 
+++

Мне хотелось несколько упростить и оптимизировать процесс загрузки страниц статического сайта в мое S3-хранилище.
<!--more-->
Подразумевается, что бакет уже работает в режиме веб-сайта. Тогда обычно этот процесс состоит из следующих шагов:

1. Удалить или проиндексировать текущее содержимое бакета.
2. Загрузить все или новые объекты (страницы сайта) в бакет.
3. Настроить права доступа к страницам.

Здесь стоит сделать оговорку - в Hugo встроен достаточно мощный [инструмент](https://gohugo.io/hosting-and-deployment/) по автоматическому деплою сайта на различные хост-площадки. Но мне бы хотелось иметь CMS-независимый инструмент, чтобы я мог использовать его и когда перееду с Hugo на другой генератор, и когда перееду с текущего хранилища куда-либо еще.

Чтобы не делать все это руками в разных местах, можно использовать, например, консольные утилиты по работе S3-хранилищами. Если хранилище имеет AWS-совместимый программный интерфейс (у меня как раз такое), то подойдет AWS-ная утилита AWS CLI. А чтобы не вызывать команды каждый раз по отдельности, объединим их в один bash-скрипт.

Для начала объявим стороковые переменные, в которых будем хранить endpoint - URL API нашего хранилища, имя бакета и каталог страниц сайта.
```
ENDPOINT="https://storage.blah.ru"
BUCKET_NAME="mybucket"
BUCKET_URL="s3://$BUCKET_NAME/"  #храним имя и URI для разных команд
SITE_PATH="public/"
```

Затем команда генерации сайта. Используем Hugo, поэтому в данном случае просто вызов `hugo`, который помещает сгенерированные страницы в каталог `public/` корневого каталога проекта. Для Lektor, например, аналогичной командой будет `lektor build`.

Далее выполняем последовательно операции, описанные в списке выше. (На самом деле все написанное ниже - полная ерунда, см. [апдейт](#update))
```
aws s3 rm $BUCKET_URL  --recursive --endpoint-url=$ENDPOINT #рекурсивно удаляем все объекты в бакете
aws s3 cp $SITE_PATH $BUCKET_URL --recursive --endpoint-url=$ENDPOINT #копируем из каталога сайта в бакет
```

Наконец нам необходимо разрешить ко всем объектам в бакете доступ на чтение. В AWS CLI существует разделение - высокоуровневые операции типа `ls`, `cp` и `rm` выполняются субкомандой `aws s3`, а более низкоуровневые обращения к API - с помощью `aws s3api`. 

Права настраиваются для каждого объекта отдельно, поэтому предварительно нам нужно получить имена всех объектов (в S3 нет такого понятия, как "путь" в традиционных ФС,нет и такого понятия, как "каталог" - объекты могут иметь одинаковые префиксы, разделяемые косой чертой). Для получения полных имен всех объектов в бакете используем команду `aws s3 ls` c опцией `--recursive`. В выводе получаем также дату загрузки и размер объекта.
```
$ aws s3 ls mysite/ --endpoint-url=https://storage.blah.ru
# вывод без --recursive - показаные первые префиксы объектов
...
                           PRE about/  
                           PRE posts/
...
2020-08-13 21:47:06       2167 404.html
2020-08-13 21:47:26       5063 index.html
$ aws s3 ls mysite/ --endpoint-url=https://storage.blah.ru --recursive
# с --recursive получаем полные имена
...
2020-08-13 21:47:06       2167 404.html
2020-08-13 21:47:06        259 about-hugo/index.html 
2020-08-13 21:47:07        259 about-us/index.html
2020-08-13 21:47:07       4410 about/index.html
2020-08-13 21:47:08       4138 archives/index.html
2020-08-13 21:47:08        256 articles/index.html
```

Пользуемся перенаправлением вывода в баше и циклом. Для разбиения вывода я обычно использовал `cut`, который позволяет разбить строку по разделителю. Но в данном случае число разделителей - пробелов - непостоянно. Поэтому проще строку превратить в массив с помощью команды `set`, и слова из строки получать по индексам - `$1`, `$2` и так далее. Также опционально в цикле прописываем вывод информирующей строки, так как выполнение `aws s3api` происходит без какого-либо выхлопа.
```
aws s3 ls $BUCKET_URL --recursive --endpoint-url=$ENDPOINT | while read line ; 
do
        set $line ;
        echo "Setting public read permission for object $4 ..." 
        aws s3api put-object-acl --bucket $BUCKET_NAME --key $4 --acl public-read --endpoint-url=$ENDPOINT ;
done
```

Итоговый вид скрипта:
```
ENDPOINT="https://storage.blah.ru"
BUCKET_NAME="mybucket"
BUCKET_URL="s3://$BUCKET_NAME/"
SITE_PATH="public/"

hugo
aws s3 rm $BUCKET_URL  --recursive --endpoint-url=$ENDPOINT
aws s3 cp $SITE_PATH $BUCKET_URL --recursive --endpoint-url=$ENDPOINT
aws s3 ls $BUCKET_URL --recursive --endpoint-url=$ENDPOINT | while read line ; 
do
        set $line ;
        echo "Setting public read permission for object $4 ..." 
        aws s3api put-object-acl --bucket $BUCKET_NAME --key $4 --acl public-read --endpoint-url=$ENDPOINT ;
done
```

#### Update

Удалять содержимое бакета и загружать его полностью снова не очень эффективно, особенно учитывая, что биллинг S3-хранилищ основан на количестве HTTP-запросов к бакетам. Поэтому вместо связки `aws s3 rm` и `aws s3 cp` выгоднее использовать команду `aws s3 sync`. Эта подкоманда синхронизирует содержимое локальных каталогов и бакетов - обновляет только измененные файлы/объекты и (с опцией `--delete`) удаляет в destination те файлы/объекты, которых не было в source. 

Более того, в `aws s3 sync` есть также опция `--acl`, которая позволяет задавать права доступа к загружаемым объектам. То есть можно не городить огород с циклом, а делать вообще все одной командой. Потрясающе.

(Disclaimer: я не то чтобы сильно растраиваюсь из-за того, что лишний раз пришлось пописать хитрые конструкции в bash.)

Тогда скрипт приобретает вообще смешные формы:
```
ENDPOINT="https://storage.blah.ru"
BUCKET_NAME="mybucket"
BUCKET_URL="s3://$BUCKET_NAME/"
SITE_PATH="public/"

hugo
aws s3 sync $SITE_PATH $BUCKET_URL --delete --acl public-read --endpoint-url=$ENDPOINT
```

Теперь генерация и загрузка страниц сайта делается одним вызовом скрипта.

Материалы для прочтения:

* https://losst.ru/tsikly-bash 
* https://stackoverflow.com/a/1478245
* https://aws.amazon.com/premiumsupport/knowledge-center/read-access-objects-s3-bucket/
* https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html