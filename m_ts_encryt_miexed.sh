#!/bin/sh
#更改变量名称
CONFILE=$1

#输出错误信息
_throw(){
	echo $1
	exit
}

#输出调试信息
_log(){
	current_time=`_get_current_time`
	echo ${current_time}:$1
}

#获取配置
_get_config(){
	SECTION=$1
	CONFILE=$2
	ITEM=$3

	for loop in `echo $ITEM | tr ',' ' '`
	do
		item=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$loop'/{gsub(/[[:blank:]]*/,"",$2);print $2;exit}' $CONFILE `
		if [ ${#item} -ne 0 ]; then
			eval $loop=$item
		fi
	done
}

#获得随机IV
_get_random_iv(){
	rand_iv=`date +%s%N | md5sum | head -c 16`
	return_iv=`echo ${rand_iv} | od -A n -v -t x1 | tr -d ' \n'`
	echo ${return_iv/0a/}
}

#获得随机串
_get_random_str(){
	rand_str=`date +%s%N | md5sum | head -c $1`
	echo ${rand_str}
}

#获取随机KEY
_get_rand_key(){
	_get_config common $CONFILE "KEY_FILE"
	count_line=`cat $KEY_FILE | wc -l`
	rand_line=`echo $(($RANDOM%$count_line))`	
	key_info=(`awk -F',' 'NR=='$rand_line'{print $1,$2,$3}' $KEY_FILE `)
}

#获得当前时间
_get_current_time(){
	current_time=`date "+%Y%m%d%H%M%S"`
	echo ${current_time}
}

#从配置文件中获取配置
_get_config common $CONFILE "MEDIA_PATH,OUTPUT_PATH,RESOLUTION,WEB_URL,LOG_PATH,SQL_LOG,TMP_PATH,APP_URL,MEDIA_ENCRYPT_PATH"

if [ ! -d $MEDIA_PATH ];then
	_throw "输入的目录不存在或者没有权限访问！"
fi

date=`date "+%Y%m%d"`
pos=0

if [ ! -d $TMP_PATH ]; then
	mkdir $TMP_PATH
fi

ext_x_key_pattern="#EXT-X-KEY:METHOD=AES-128,URI=\"__KEY__\",IV=__IV__"
#取得要处理的文件并处理 
#file_list=`find $MEDIA_ENCRYPT_PATH  -name  '*.m3u8'`
#备份原来的文件
#for file in $file_list
#do
#	old_file=${file/\.m3u8/.old}
#	if [ ! -f $old_file ]; then
#		cp ${file} ${old_file}	
#	fi
#	cp ${old_file} ${file}
#done

file_list=`find $MEDIA_ENCRYPT_PATH  -name  '*.m3u8'`
#备份原来的文件
for file in $file_list
do
	let pos=pos+1
	
	_log "开始处理第$pos个文件[$file]"
	output_name=`basename $file .m3u8`
	dir_name=`dirname $file`

	#加入版本
	#检查是否有版本号，没有的加入
	#is_version=`awk '/EXT-X-VERSION/{print $1}' $file | wc -l `
	#if [ $is_version -eq 0 ]; then
	#	sed -i '1 a\#EXT-X-VERSION:2' $file
	#fi
		
	#获取ts文件列表
	ts_list=`cat $file | grep '.ts'`
	ts_pos=0
	
	_log "开始处理切片"
	for ts in $ts_list
	do
		ts=${ts/$WEB_URL/$MEDIA_ENCRYPT_PATH}
		#let ts_pos=ts_pos+1
		#if [ $ts_pos -le 3 ]; then
		#	continue
		#fi	

		seq_name=`basename $ts .ts`
		#seq_full_name=${ts/\.ts/\.seq}

		#获取需要加入EXT-X-KEY的位置
		ts_info=(`awk '/'$seq_name'/{print FNR,$0}' $file `)
		line=${ts_info[0]}
		random_name=`_get_random_str 20`
		sed -i ''''$line'''s/'''$seq_name'''/'''$random_name'''/' $file
		mv ${dir_name}/${seq_name}.ts ${dir_name}/${random_name}.ts

		#if [ $ts_pos -eq 4 ]; then
			#删除原来的ext-x-key
			#let tmp_line=line
			#is_x_key=`awk 'NR=='$tmp_line'&&/EXT-X-KEY/' $file | wc -l`
			#if [ $is_x_key -eq 1 ]; then
			#	sed -i ${tmp_line}'d' $file
			#	let line=line-1
			#fi
			#_get_rand_key
			#secret_id=${key_info[0]}
			#secret=${key_info[2]}

			#iv=`_get_random_iv`
			#key_url=${APP_URL}"?id="${secret_id}
			#ext_x_key=${ext_x_key_pattern}
			#ext_x_key=${ext_x_key/__KEY__/${key_url}}
			#ext_x_key=${ext_x_key/__IV__/${iv}}
			#sed -i ''''$line''' a'''$ext_x_key'''' $file
		#fi
		
		#加密
		#_log "开始加密第${ts_pos}个切片"
		#openssl aes-128-cbc -v -p -iv ${iv}  -K ${secret} -in $ts -out $seq_full_name &>/dev/null
	done
	#替换加密后的切片
	#sed -i '11,$ s/\.ts/\.seq/g' $file 
	_log "处理完成{$file}"
done

_log "输出日志到${SQL_LOG}"
