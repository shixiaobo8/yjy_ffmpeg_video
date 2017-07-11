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
	echo $1
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

_get_random_str(){
        rand_iv=`date +%s%N | md5sum | head -c $1`
	echo ${rand_iv}
        #return_iv=`echo ${rand_iv} | od -A n -v -t x1 | tr -d ' \n'`
        #echo ${return_iv/0a/}
}

#从配置文件中获取配置
_get_config common $CONFILE "MEDIA_PATH,OUTPUT_PATH,THUMB_PATH,RESOLUTION,WEB_URL,APP_URL,TMP_PATH,KEY_FILE"

_get_config log $CONFILE "LOG_PATH,SQL_LOG,ERROR_LOG"

if [ ! -d $MEDIA_PATH ];then
	_throw "输入的目录不存在或者没有权限访问！"
fi

date=`date "+%Y%m%d"`
pos=0

if [ ! -d $TMP_PATH ]; then
	mkdir $TMP_PATH
fi

#取得要处理的文件并处理 
file_list=`find $MEDIA_PATH  -name  '*.mp4'`
for file in $file_list
do
	let pos=pos+1
	_log "开始处理第$pos个文件[$file]"
	output_name=`basename $file .mp4`
	tmp_file=${TMP_PATH}/${output_name}'_tmp.mp4'
	file_name=`_get_random_str 16`
	#转码
	#同尺寸的也得转码，否则会出错，可能与视频格式有关
	if [ ! -f $tmp_file ]; then
		_log "开始转码生成临时文件$tmp_file"
		ffmpeg -i $file -s $RESOLUTION $tmp_file &>/dev/null 
		if [ $? -ne 0 ]; then
			_log "转换尺寸失败"
			continue
		fi
		_log "转码成功"
	else
		_log "临时文件已经存在，跳过转码"	
	fi
	
	#生成缩略图
	thumb_path=${THUMB_PATH}"/"${date}"/"
	if [ ! -d $thumb_path ]; then
		mkdir -p $thumb_path
	fi	
	thumb_url=${thumb_path}${file_name}".jpg"	
	ffmpeg -i $tmp_file -y -f mjpeg -ss 3 -t 0.001 -s 720x406 $thumb_url &>/dev/null 
	if [ ! -f $tmp_file ]; then 
		#删除临时文件
		rm -rf $tmp_file
		_log "生成缩略图${thumb_url}失败"
		echo ${file} >> $ERROR_LOG 
		continue
	else
		_log "生成缩略图${thumb_url}"
	fi
	#获取视频时长
	duration=`ffmpeg -i ${tmp_file} 2>&1 | awk -F ':' '$1~/Duration/{print $2 * 3600 + $3*60 + $4;}'`

	#生成ts
	random_path=`_get_random_str 8`
	output_full_path=$OUTPUT_PATH"/"$date"/"$random_path
	if [ ! -d $output_full_path ]; then
		mkdir -p $output_full_path
	fi	
	cd $output_full_path
	_log "开始生成ts"${output_full_path} 
	ffmpeg -y -i $tmp_file -f mpegts -c:v copy -c:a copy  -vbsf h264_mp4toannexb $file_name.ts &>/dev/null
	if [ $? -ne 0 ]; then
		_log "生成ts失败"
		continue
	fi
	_log "生成ts成功"
	
	_log "开始生成切片"${file_name}.m3u8
	#切片
	file_url=${WEB_URL}${date}"/"${random_path}"/"${file_name}".m3u8"
	segmenter -y -i $file_name.ts -d 10 -p $file_name -m $file_name.m3u8  -u ${WEB_URL}${date}/${random_path}/ &>/dev/null
	_log "生成切片成功"
	
	#统计切片大小
	ts_size=`du -sh $file_name.ts`
	#删除切片
 	#rm $file_name.ts
	
	#rm $tmp_file
	echo ${output_name},${thumb_url},${file},${RESOLUTION},${file_url},${duration},$ts_size >> $SQL_LOG
	# 使用php aes加密类加密ts文件
	all_ts=`find ${output_full_path} -name "*.ts"`
	cd ${output_full_path}
	for t_s in ${all_ts}
	do
		echo -e "正在加密第"$pos "个ts文件"$t_s
		php /root/scripts/aes.php $t_s $t_s
	done
done

_log "输出日志到${SQL_LOG}"
