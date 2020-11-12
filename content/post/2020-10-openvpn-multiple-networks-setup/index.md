+++
author = "Letchik Bulochkin"
title = "Объединение нескольких удаленных подсетей с помощью OpenVPN"
date = "2020-10-29"
description = "...и сервера в облаке"
images = ["thumb.jpg"]
tags = [
    "OpenVPN", "EasyRSA", "Linux", "networking", "VPN"
] 
+++

**Задача:** объединить несколько территориально удаленных подсетей с помощью VPN-тоннелей и OpenVPN-сервера, развернутого в облаке.

В результате должна получиться следующая сетевая схема:

<img src="/post/2020-10-openvpn-multiple-networks-setup/base_site_network_configuration.png" alt="drawing" width="700"/>

<!--more-->

Необходимо настроить доступ к каждой из трех удаленных подсетей (назовем их условно Franz, Emil и Gustav), а также разрешить доступ с какого-либо мобильного устройства, находящегося вне этих подсетей (Hugo). В качестве сервера используется ВМ в Облаке (в моем случае - в AWS-like облачной платформе) с CentOS 7.5, в качестве клиентов - роутеры Keenetic с прошивкой NDMS и Android-смартфон с клиентом OpenVPN.

Весь процесс можно разделить на четыре этапа. Начнём с кофигурации сервера, развернутого в облаке.

### Этап 1. Конфигурация сервера
Устанавливаем OpenVPN, EasyRSA и iptables:
```
$ yum -y install epel-release
$ yum -y install openvpn easy-rsa iprables-services
```

В каталоге `/etc/openvpn/` создаем файл конфигурации сервера `server.conf`. В него вносим директивы, которые OpenVPN применит при запуске. Ниже расскажу про отдельные директивы, которые я применил для своей конфигурации, и текст конфига целиком.

`proto tcp` - выбор протокола 4 уровня для установки соединения. Можно выбрать между TCP и UDP. TCP обеспечивает более надежное соединение, UDP - более быстрое соединение.

`port 1194` - порт по умолчанию для OpenVPN-сервера. Можно выбрать любой другой незанятый порт, чтобы избежать целевой атаки.

`user nobody`, `group nobody` - пользователь и группа, от которых запускается OpenVPN-сервер. Запуск с минимальными привилегиями - наиболее безопасный вариант.

`persist key`, `persist tun` - не пересоздавать туннельный интерфейс и не считывать заново файлы ключей клиентов при перезапуске сервера.

`keepalive 5 60` - сервер будет пинговать подключенных клиентов каждые 5 минут и пересоздавать тоннель в случае отсутствия ответа в течении 60 секунд.

`topology subnet` - выбор топологии туннельного соединения. Помимо режима `subnet` также поддерживаются режимы `p2p` (не совместим с Windows-клиентами) и `net30` - когда на каждый тоннель клиент-сервер выделяется подсеть /30. Этот режим включен по умолчанию в OpenVPN 2.3, но в последней на текущий момент версии 2.4 оставлен только для обратной совместимости - рекомендуется использовать `subnet`.

`ifconfig-pool-persist ipp.txt` - при рестарте сервера назначать адреса клиентам согласно файлу ipp.txt. Так можно закреплять постоянные адреса для каждого клиентского шлюза в тоннелях.  

`client-to-client` - разрешить обмен данными между клиентами.

`server 10.8.0.0 255.255.255.0` - эта директива равнозначна применению следующих директив:

* `mode server` - работать в режиме сервера;
* `tls-server` - сервер также является TLS-сервером;
* `push "topology subnet"` - директива `push` добавляет данный ей параметр в конфигурации подключаемых клиентов, в данном случае - режим работы `subnet`;
* `ifconfig 10.8.0.1 255.255.255.0` - сетевая конфигурация тоннельного интерфейса сервера;
* `push "route-gateway 10.8.0.2"` - эта опция должна указывать клиентам использовать адрес тоннельного интерфейса сервера в качестве шлюза. В документации OpenVPN описано, что в случае использования директивы `server` в качестве шлюза устанавливается второй адрес в выбранной подсети, хотя tun-интерфейс на сервере получает .1 адрес. Почему - неясно, но в конфиге потребуется прописать `push "route-gateway 10.8.0.1"` напрямую.

`route 192.168.2.0 255.255.255.0` - добавление маршрута в клиентскую подсеть. В директиве указывается подсеть, маска подсети, а шлюз подставляется из первого параметра директивы `ifconfig`. Аналогично маршруты до соседних клиентских подсетей передаются каждому клиенту указанием директивы `route` в качестве параметра директиве `push`.

`verb 4`, `log-append /var/log/openvpn/ovpn.log` - уровень подробности лога, абстрактная величина. Уровни от 1 до 4 являются достаточными для обычного использования, начиная с 5 уровня в лог добавляется специфичная дебаг-информация. `log-append` - добавлять новые записи в указанный файл.

`status /var/log/openvpn/status.log 60`, `status-version 2` - логировать отдельно информацию о статусе сервера каждые 60 секунд. Информация о статусе содержит имена подключенных клиентов, IP-адреса их тоннельных шлюзов, объем переданной и полученной информации, время подключения.

Конфигурация в полном виде выглядит следующим образом:
```
proto tcp
port 1194

user nobody
group nobody

persist-key
persist-tun

keepalive 5 60

dev tun
topology subnet
client-to-client
ifconfig-pool-persist ipp.txt
server 10.100.0.0 255.255.255.0

route 192.168.1.0 255.255.255.0
route 192.168.2.0 255.255.255.0
route 192.168.3.0 255.255.255.0
push "route 172.33.0.0 255.255.0.0" # VPC route
push "route 192.168.1.0 255.255.255.0" 
push "route 192.168.2.0 255.255.255.0" 
push "route 192.168.3.0 255.255.255.0" 

client-config-dir ccd

# encryption stuff
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem

# allow multiple clients with same name to connect
duplicate-cn

# lz4 believed to be better compression algorithm then lz0
# last two options believed to speed up decompression
comp-lzo
sndbuf 0
rcvbuf 0

verb 4
status /var/log/openvpn/status.log 60
status-version 2
log-append /var/log/openvpn/ovpn.log
```

Создадим необходимые файлы и каталоги - для логов, конфигурации IP-адресов тоннельных интерфейсов и клиентских конфигураций. В файле `/etc/openvpn/ipp.txt` пропишем адреса тоннельной подсети для каждого из клиентов:
```
franz,10.8.0.2
emil,10.8.0.3
friedrich,10.8.0.4
hugo,10.8.0.5
```

Еще одна важная директива - `client-config-dir ccd`. В этой директиве указывается каталог, в котором хранятся специфичные для каждого клиента конфигурационные файлы. В нашем случае клиентские конфиги будут содержать одну директиву - `iroute`, которая будет сообщать серверу, какому клиенту направлять трафик к каким адресам назначения. Например, в файл `/etc/openvpn/ccd/emil` необходимо добавить следующее:
```
iroute 192.168.3.0 255.255.255.0
```
Важно понимать разницу между директивами `route` и `iroute`. Первая добавляет в локальную таблицу маршрутизации сервера маршрут до удаленной подсети, подключенной через VPN. Шлюзом указывается тоннельный интерфейс сервера, трафик на котором обрабатывает OpenVPN-сервер. При этом сам OpenVPN-сервер должен знать, какому из подключенных клиентов отправить поступающие пакеты. Для этого в клиентских конфигах прописывается директива `iroute`, параметром которой является подсеть клиента. 

### Этап 2. Создание ключей и сертификатов
После окончания формирования конфигов начинаем создавать сертификаты и ключи для сервера и клиентов. Скопируем скрипты для генерации сертификатов и создадим каталог, где будут хранится сгенерированные ключи:
```
cp -rf /usr/share/easy-rsa/3.0/* /etc/openvpn/easy-rsa/
mkdir -p /etc/openvpn/easy-rsa/keys
```
Отредактируем файл переменных `/etc/openvpn/easy-rsa/vars`, используемых для генерации ключей. Пример заполнения:
```
export KEY_COUNTRY="RU"
export KEY_PROVINCE="RU"
export KEY_CITY="Moscow"
export KEY_ORG="Example"
export KEY_EMAIL="user@example.com"
export KEY_OU="MyOrganizationalUnit"
```
Сделаем файл исполняемым и экспортируем переменные. Далее приступаем к генерации ключей и сертфикатов для сервера и клиентов.
```
$ cd /etc/openvpn/easy-rsa
$ chmod +x ./vars
$ source ./vars
$ ./easyrsa init-pki
$ ./easyrsa build-ca nopass
$ ./easyrsa gen-dh
$ ./easyrsa gen-req server nopass
$ ./easyrsa sign-req server server
$ ./easyrsa gen-req emil nopass
$ ./easyrsa sign-req client emil
```
Копируем созданные файлы для сервера - в каталог `/etc/openvpn/`, для клиента - на локальную машину или в домашний каталог для включения их в клиентские конфигурации.
```
$ cd /etc/openvpn
$ cp easy-rsa/pki/ca.crt ./  # копируем файлы сервера
$ cp easy-rsa/pki/dh.pem ./dh2048.pem
$ cp easy-rsa/pki/issued/server.crt ./
$ cp easy-rsa/pki/private/server.key ./
$ cp easy-rsa/pki/ca.crt ~/ # сертификат сервера также понадобится для клиента
$ cp easy-rsa/pki/private/emil.key ~/
```

### Этап 3. Прочие настройки сервера
Еще несколько пунктов перед тем как перейти к конфигурации клиентов. Разрешим IP-форвардинг в системе:
```
$ echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
$ systemctl restart network.service
```
Настроим SELinux:
```
$ cd /etc/openvpn
$ restorecon -R
```
Используем iptables вместо firewalld:
```
$ systemctl stop firewalld
$ systemctl disable firewalld
$ systemctl enable iptables
$ systemctl start iptables
$ iptables -F
$ iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
$ service iptables save
$ service iptables restart
```
Конфигурация iptables может быть иной, в зависимости от целей и задач. iptables - мощнейший инструмент, в данной статье мы не будем останавливаться на нём подробно.

Рестартуем сеть на сервере и запускаем сервер OpenVPN:
```
$ systemctl restart network
$ systemctl -f enable openvpn@server.service
$ systemctl start openvpn@server.service
```
Не забудьте прописать в настройках фаерволла сервера разрешающие правила для TCP для выбранного порта.

### Этап 4. Настройка клиентов
Далее приступаем к формированию клиентских конфигураций. Клиентские конфигурации будут включать в себя директивы OpenVPN, сертификат сервера и приватный ключ клиента - прямым включением в файл конфигурации. Из директив OpenVPN отдельно стоит отметить следующие:

`resolv-retry infinite` - не прекращать попытки резолвить DNS-имя сервера. Пригодится, если вы подсключаетесь не по IP, а через доменное имя.

`pull` - получать данные от сервера. Директива необходима, чтобы корректно отработали директивы `push` на сервере.

`nobind` - позволить OpenVPN самому выбирать порт для исходящего подключения. Пригодится, если вы планируете открыть на маршрутизаторе несколько тоннелей.

Пример конфигурации для клиента Emil целиком:
```
client
dev tun
remote 200.200.62.63
proto tcp
port 1194
resolv-retry infinite
pull
nobind
user nobody
group nobody
persist-key
persist-tun
comp-lzo
verb 3
<ca>
-----BEGIN CERTIFICATE-----
# ca.crt paste here #
-----END CERTIFICATE-----
</ca>
<cert>
-----BEGIN CERTIFICATE-----
# server.crt paste here #
-----END CERTIFICATE-----
</cert>
<key>
-----BEGIN PRIVATE KEY-----
# emil.key paste here #
-----END PRIVATE KEY-----
</key>
```
Теперь можно переходить к настройке маршрутизатора. Как было сказано выше, в моем случае объединяемые подсети управляются маршрутизаторами Keenetic (бывший ZyXEL) с прошивкой NDMS. Для поднятия VPN тоннеля на роутер необходимо доустановить компонент OpenVPN client and server. Это можно сделать в разделе *Management -> System settings -> Component options*. В списке находим нужный компонент и устанавлиаем галочку. После роутер перезагрузится для установки обновлений и необходимого компонента.

<img src="/post/2020-10-openvpn-multiple-networks-setup/screen1.png" alt="General settings" width="700"/>
<img src="/post/2020-10-openvpn-multiple-networks-setup/screen2.png" alt="Component options" width="700"/>

После перезагрузки заходим на страницу *Internet -> Other connections -> VPN connections*. В списке доступных типов VPN-соединений найдем OpenVPN. Далее нам останется прописать имя для соединения, скопировать конфигурацию и не забыть проставить пункт *Obtain routes from the remote side*.

<img src="/post/2020-10-openvpn-multiple-networks-setup/screen3.png" alt="New VPN connection" width="400"/>

Последним этапом необходимо добавить разрешающее правило для IP-пакетов (не TCP!) для нашего подключения. Проверено: добавления разрешающего правила для TCP работать не будет. Добавляем правило в разделе *Network rules -> Firewall*.

<img src="/post/2020-10-openvpn-multiple-networks-setup/screen4.png" alt="Create Firewall rule" width="700" style="display: block; margin-left: auto; margin-right: auto"/>

Теперь наше подключение должно работать. Аналогичным образом настраиваем оставшиеся маршрутизаторы.

Материалы для чтения:

* https://community.openvpn.net/openvpn/wiki/Topology
* https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/
* https://forums.openvpn.net/viewtopic.php?t=26839
* https://www.dmosk.ru/miniinstruktions.php?mini=openvpn-easyrsa3
* https://itdraft.ru/2019/04/18/ustanovka-i-nastrojka-openvpn-klienta-i-servera-i-easy-rsa-3-v-centos-7/
* https://vk.cc/aCoIkv - инструкция с сайта Keenetic, взятая за основу
* https://vk.cc/aCoIqc - описание проблемы с разрешающим правилом фаерволла
