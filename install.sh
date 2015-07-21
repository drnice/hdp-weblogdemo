#!/bin/bash

### Config:
dir="$(dirname $0)"

if ! . $dir/conf.sh
then
	echo "Unable to load configuration file $dir/conf.sh!  Aborting..."
	exit 1
fi

if ! . $dir/distro.sh
then
	echo "Unable to load distro detection script $dir/distro.sh!  Aborting..."
	exit 1
fi
##

# This needs root
if [[ $EUID -ne 0 ]]
then
	echo "This script must be run as root."
	echo
	echo "RHEL/CentOS:  execute 'su -' and then run this script again"
	echo "Ubuntu:       run 'sudo $0'"
fi

##### Make sure packages are installed
if ! check_package_installed $apache_pkg
then
	if ! $install_cmd $apache_pkg
	then
		echo "Error installing $apache_pkg!  Aborting..."
		exit 1
	fi
else
	echo "Apache already installed; skipping install."
fi

##### DR Mysql installation
if ! check_package_installed $mysql_pkg
then
	if ! $install_cmd $mysql_pkg
	then
		echo "Error installing $mysql_pkg!  Aborting..."
		exit 1
	fi
else
	echo "MySQL already installed; skipping install."
fi

##### DR php installation
if ! check_package_installed $php_pkg
then
        if ! $install_cmd $php_pkg
        then
                echo "Error installing $php_pkg!  Aborting..."
                exit 1
        fi
else
        echo "PHP already installed; skipping install."
fi

###### DR MySQL Database setup 
cat << EOF > "$dir/createdb.sql"
CREATE DATABASE IF NOT EXISTS test;
use test;
DROP TABLE IF EXISTS admin;
CREATE TABLE admin ( id INT PRIMARY KEY AUTO_INCREMENT, username VARCHAR(30) UNIQUE, passcode VARCHAR(30) );
insert into test.admin values(1,'drice','hadoop');
insert into test.admin values(2,'eorgad','hadoop');
insert into test.admin values(3,'rmccollam','hadoop');
insert into test.admin values(4,'tbenton','hadoop');
insert into test.admin values(5,'agrande','hadoop');
insert into test.admin values(6,'bdubois','hadoop');
insert into test.admin values(7,'mcarrillo','hadoop');
grant all on test.* to 'drice'@'%' identified by 'hadoop';
flush privileges;
EOF

`mysql < $dir/createdb.sql`

#if ! . $dir/distro.sh
#then
#        echo "Unable to load distro detection script $dir/distro.sh!  Aborting..."
#        exit 1
#fi


######## DR Config.php setup
cat << EOF > "$dir/config.php";
<?php
define('DB_SERVER', 'localhost');
define('DB_USERNAME', 'drice');
define('DB_PASSWORD', 'hadoop');
define('DB_DATABASE', 'test');
$db = mysqli_connect(DB_SERVER,DB_USERNAME,DB_PASSWORD,DB_DATABASE);
?>
EOF


cat << EOF > "$dir/login.php";
<?php
include("config.php");
session_start();
if($_SERVER["REQUEST_METHOD"] == "POST")
{
// username and password sent from Form
$myusername=mysqli_real_escape_string($db,$_POST['username']);
$mypassword=mysqli_real_escape_string($db,$_POST['password']);

//echo $myusername;
//echo $mypassword;

$sql="SELECT id FROM admin WHERE username='$myusername' and passcode='$mypassword'";
$result=mysqli_query($db,$sql);
$row=mysqli_fetch_array($result,MYSQLI_ASSOC);
$active=$row['active'];
$count=mysqli_num_rows($result);


// If result matched $myusername and $mypassword, table row must be 1 row
if($count==1)
{
//session_register("myusername");
$_SESSION['login_user']=$myusername;

header("location: welcome.php");
}
else
{
$error="Your Login Name or Password is invalid";
}
}
?>
<form action="" method="post">
<label>UserName :</label>
<input type="text" name="username"/><br />
<label>Password :</label>
<input type="password" name="password"/><br/>
<input type="submit" value=" Submit "/><br />
</form>
EOF

read -n1 -r -p "Press space to continue..." key

##### Set up a new site
if ! mkdir -p "/opt/$sitename/www"
then
	echo "Error creating /opt/$sitename/www!  Aborting..."
	exit 1
fi

if ! mkdir -p "/opt/$sitename/weblogs"
then
	echo "Error creating /opt/$sitename/weblogs!  Aborting..."
	exit 1
fi

if ! cp -r bootstrap/* "/opt/$sitename/www/"
then
	echo "Error copying Bootstrap Framework to /opt/$sitename/www!  Aborting..."
	exit 1
fi

cat << EOF > "$apache_conf_dir/$sitename.conf"
# Setup for $sitename
Listen $port
<VirtualHost *:$port>
  DocumentRoot /opt/$sitename/www
  ErrorLog $weberrorlog
  CustomLog $webaccesslog combined
</VirtualHost>
EOF


##### Login Screen DR




cat << EOF > "/opt/$sitename/www/index.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>$sitename</title>

    <!-- Bootstrap -->
    <link href="css/bootstrap.min.css" rel="stylesheet">
    <link href="css/custom.css" rel="stylesheet">

    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
	<script>
		function handleButton(btn) {
			var url = "btn.html?btn=" + btn;

			var xmlHttp = new XMLHttpRequest();
			xmlHttp.open("GET", url, false);
			xmlHttp.send(null);
			\$('#btn_notify').html('<div class="alert alert-warning"><span>Click on ' + btn + ' recorded!</span></div>')
			setTimeout(function() {
				\$("div.alert").fadeTo(500, 0).slideUp(500, function(){
					\$("div.alert").remove();
				})
			}, 2000);
		}
	</script>
  </head>
  <body>
    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
    <!-- Include all compiled plugins (below), or include individual files as needed -->
    <script src="js/bootstrap.min.js"></script>

	<div class="jumbotron">
		<div class="container">
			<div class="row text-center" id="rowtime">
				<strong><h1>Welcome to $sitetitle</h1></strong>
				<h2>$sitedesc</h2>
			</div>
		</div>
	</div>

	<div class="container">
		<div class="row">
			<div class="column col=md-4"></div>
			<div class="column col=md-4 flash fade in out text-center" style="height: 3em" id="btn_notify"></div>
			<div class="column col=md-4"></div>
		</div>
	</div>

	<div class="container">
		<div class="row text-center"><h2>$category1:</h2></div>
		<div class="row">
			<div class="column col-md-4 text-left">
				<button class="btn btn-lg btn-block btn-primary" onClick="handleButton('$c1btn1');">$c1btn1</button>
			</div>
			<div class="column col-md-4 text-center">
				<button class="btn btn-lg btn-block btn-warning" onClick="handleButton('$c1btn2');">$c1btn2</button>
			</div>
			<div class="column col-md-4 text-right">
				<button class="btn btn-lg btn-block btn-danger" onClick="handleButton('$c1btn3');">$c1btn3</button>
			</div>
		</div>
		<div class="row text-center"><h2>$category2:</h2></div>
		<div class="row">
			<div class="column col-md-4 text-left">
				<button class="btn btn-lg btn-block btn-success" onClick="handleButton('$c2btn1');">$c2btn1</button>
			</div>
			<div class="column col-md-4 text-center">
				<button class="btn btn-lg btn-block btn-info" onClick="handleButton('$c2btn2');">$c2btn2</button>
			</div>
			<div class="column col-md-4 text-right">
				<button class="btn btn-lg btn-block btn-default" onClick="handleButton('$c2btn3');">$c2btn3</button>
			</div>
		</div>
		<div class="row text-center"><h2>Broken links:</h2></div>
		<div class="row">
			<div class="column col-md-3">&nbsp;</div>
			<div class="column col-md-3 text-left"><a href="badpage1.html">Broken link 1</a></div>
			<div class="column col-md-3 text-right"><a href="badpage2.html">Broken link 2</a></div>
			<div class="column col-md-3">&nbsp;</div>
		</div>
	</div>

  </body>
</html>
EOF

cat << EOF > "/opt/$sitename/www/btn.html"
<html>
<head><title>Button Handler</title></head>
<body>This space intentionally left blank.</body>
</html>
EOF

if ! $enable_site_cmd $sitename
then
	echo "Unable to enable $sitename site!  Aborting..."
	exit 1
fi

if ! $apache_restart_cmd
then
	echo "Unable to restart apache!  Aborting..."
	exit 1
fi

##### Set up flume
if ! mkdir -p "/opt/$sitename/flume/flume.out"
then
	echo "Unable to create /opt/$sitename/flume/flume.out!  Aborting..."
	exit 1
fi

cat << EOF > "/opt/$sitename/flume/avroaccess.conf"
#http://flume.apache.org/FlumeUserGuide.html#avro-source
collector.sources = AvroIn
collector.sources.AvroIn.type = avro
collector.sources.AvroIn.bind = 0.0.0.0
collector.sources.AvroIn.port = 4545
collector.sources.AvroIn.channels = mc1 mc2

## Channels ##
## Source writes to 2 channels, one for each sink
collector.channels = mc1 mc2

#http://flume.apache.org/FlumeUserGuide.html#memory-channel

collector.channels.mc1.type = memory
collector.channels.mc1.capacity = 100

collector.channels.mc2.type = memory
collector.channels.mc2.capacity = 100

## Sinks ##
collector.sinks = LocalOut HadoopOut

## Write copy to Local Filesystem
#http://flume.apache.org/FlumeUserGuide.html#file-roll-sink
collector.sinks.LocalOut.type = file_roll
collector.sinks.LocalOut.sink.directory = /opt/$sitename/flume/flume.out
collector.sinks.LocalOut.sink.rollInterval = 0
collector.sinks.LocalOut.channel = mc1

## Write to HDFS
#http://flume.apache.org/FlumeUserGuide.html#hdfs-sink
collector.sinks.HadoopOut.type = hdfs
collector.sinks.HadoopOut.channel = mc2
#collector.sinks.HadoopOut.hdfs.path = /user/$hadoopuser/web-access-logs/%{log_type}/%y%m%d
collector.sinks.HadoopOut.hdfs.path = $hdfsaccesspath
collector.sinks.HadoopOut.hdfs.fileType = DataStream
collector.sinks.HadoopOut.hdfs.writeFormat = Text
collector.sinks.HadoopOut.hdfs.rollSize = 0
collector.sinks.HadoopOut.hdfs.rollCount = 10000
collector.sinks.HadoopOut.hdfs.rollInterval = 600
EOF

cat << EOF > "/opt/$sitename/flume/avroerror.conf"
#http://flume.apache.org/FlumeUserGuide.html#avro-source
collector.sources = AvroIn
collector.sources.AvroIn.type = avro
collector.sources.AvroIn.bind = 0.0.0.0
collector.sources.AvroIn.port = 4546
collector.sources.AvroIn.channels = mc1 mc2

## Channels ##
## Source writes to 2 channels, one for each sink
collector.channels = mc1 mc2

#http://flume.apache.org/FlumeUserGuide.html#memory-channel

collector.channels.mc1.type = memory
collector.channels.mc1.capacity = 100

collector.channels.mc2.type = memory
collector.channels.mc2.capacity = 100

## Sinks ##
collector.sinks = LocalOut HadoopOut

## Write copy to Local Filesystem
#http://flume.apache.org/FlumeUserGuide.html#file-roll-sink
collector.sinks.LocalOut.type = file_roll
collector.sinks.LocalOut.sink.directory = /opt/$sitename/flume/flume.out
collector.sinks.LocalOut.sink.rollInterval = 0
collector.sinks.LocalOut.channel = mc1

## Write to HDFS
#http://flume.apache.org/FlumeUserGuide.html#hdfs-sink
collector.sinks.HadoopOut.type = hdfs
collector.sinks.HadoopOut.channel = mc2
#collector.sinks.HadoopOut.hdfs.path = /user/$hadoopuser/web-error-logs/%{log_type}/%y%m%d
collector.sinks.HadoopOut.hdfs.path = $hdfserrorpath
collector.sinks.HadoopOut.hdfs.fileType = DataStream
collector.sinks.HadoopOut.hdfs.writeFormat = Text
collector.sinks.HadoopOut.hdfs.rollSize = 0
collector.sinks.HadoopOut.hdfs.rollCount = 10000
collector.sinks.HadoopOut.hdfs.rollInterval = 600
EOF


cat << EOF > "/opt/$sitename/flume/access.conf"
# http://flume.apache.org/FlumeUserGuide.html#exec-source
source_agent.sources = apache_server
source_agent.sources.apache_server.type = exec
source_agent.sources.apache_server.command = tail -f $webaccesslog
source_agent.sources.apache_server.batchSize = 1
source_agent.sources.apache_server.channels = memoryChannel
source_agent.sources.apache_server.interceptors = itime ihost itype

# http://flume.apache.org/FlumeUserGuide.html#timestamp-interceptor
source_agent.sources.apache_server.interceptors.itime.type = timestamp

# http://flume.apache.org/FlumeUserGuide.html#host-interceptor
source_agent.sources.apache_server.interceptors.ihost.type = host
source_agent.sources.apache_server.interceptors.ihost.useIP = false
source_agent.sources.apache_server.interceptors.ihost.hostHeader = host

# http://flume.apache.org/FlumeUserGuide.html#static-interceptor
source_agent.sources.apache_server.interceptors.itype.type = static
source_agent.sources.apache_server.interceptors.itype.key = log_type
source_agent.sources.apache_server.interceptors.itype.value = apache_access_combined

# http://flume.apache.org/FlumeUserGuide.html#memory-channel
source_agent.channels = memoryChannel
source_agent.channels.memoryChannel.type = memory
source_agent.channels.memoryChannel.capacity = 100

## Send to Flume Collector on Hadoop Node
# http://flume.apache.org/FlumeUserGuide.html#avro-sink
source_agent.sinks = avro_sink
source_agent.sinks.avro_sink.type = avro
source_agent.sinks.avro_sink.channel = memoryChannel
source_agent.sinks.avro_sink.hostname = localhost
source_agent.sinks.avro_sink.port = 4545
EOF

cat << EOF > "/opt/$sitename/flume/error.conf"
# http://flume.apache.org/FlumeUserGuide.html#exec-source
source_agent.sources = apache_server
source_agent.sources.apache_server.type = exec
source_agent.sources.apache_server.command = tail -f $weberrorlog
source_agent.sources.apache_server.batchSize = 1
source_agent.sources.apache_server.channels = memoryChannel
source_agent.sources.apache_server.interceptors = itime ihost itype

# http://flume.apache.org/FlumeUserGuide.html#timestamp-interceptor
source_agent.sources.apache_server.interceptors.itime.type = timestamp

# http://flume.apache.org/FlumeUserGuide.html#host-interceptor
source_agent.sources.apache_server.interceptors.ihost.type = host
source_agent.sources.apache_server.interceptors.ihost.useIP = false
source_agent.sources.apache_server.interceptors.ihost.hostHeader = host

# http://flume.apache.org/FlumeUserGuide.html#static-interceptor
source_agent.sources.apache_server.interceptors.itype.type = static
source_agent.sources.apache_server.interceptors.itype.key = log_type
source_agent.sources.apache_server.interceptors.itype.value = apache_access_combined

# http://flume.apache.org/FlumeUserGuide.html#memory-channel
source_agent.channels = memoryChannel
source_agent.channels.memoryChannel.type = memory
source_agent.channels.memoryChannel.capacity = 100

## Send to Flume Collector on Hadoop Node
# http://flume.apache.org/FlumeUserGuide.html#avro-sink
source_agent.sinks = avro_sink
source_agent.sinks.avro_sink.type = avro
source_agent.sinks.avro_sink.channel = memoryChannel
source_agent.sinks.avro_sink.hostname = localhost
source_agent.sinks.avro_sink.port = 4546
EOF


##### Set up hive
echo ; echo ; echo
echo Creating hive table $hiveaccesslog...
# FIXME: This would work much better with the hive -e syntax but I have been having
# problems formatting/escaping it properly to do that.  Currently error detection will
# not function correctly (the exit from hive will always return 0).
hive <<EOL
CREATE EXTERNAL TABLE $hiveaccesslog (
\`ip\` STRING,
\`time\` STRING,
\`method\` STRING,
\`uri\` STRING,
\`protocol\` STRING,
\`status\` STRING,
\`bytes_sent\` STRING,
\`referer\` STRING,
\`useragent\` STRING
) ROW FORMAT SERDE "org.apache.hadoop.hive.contrib.serde2.RegexSerDe"
WITH SERDEPROPERTIES (
'input.regex'='^(\\\S+) \\\S+ \\\S+ \\\[([^\\\[]+)\\\] "(\\\w+) (\\\S+) (\\\S+)" (\\\d+) (\\\S+) "([^"]+)" "([^"]+)".*'
) STORED AS TEXTFILE LOCATION "$hdfsaccesspath";
exit;
EOL
if [[ $? -ne 0 ]]
then
	echo "Unable to create $hiveaccesslog!  Aborting..."
	exit 1
fi
echo Creating hive table $hiverrorlog...
hive <<EOL
CREATE EXTERNAL TABLE $hiveerrorlog (
\`time\` STRING,
\`status\` STRING,
\`ip\` STRING,
\`text\` STRING
) ROW FORMAT SERDE "org.apache.hadoop.hive.contrib.serde2.RegexSerDe"
WITH SERDEPROPERTIES (
'input.regex'='^\\\[([^\\\[]+)\\\] \\\[([^\\\[]+)\\\] \\\[([^\\\[]+)\\\] (.*)$'
) STORED AS TEXTFILE LOCATION "$hdfserrorpath";
exit;
EOL

echo "Finished.  Now run 'run.sh' to start flume and begin collecting data."
