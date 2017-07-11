#!/bin/bash
ts_dir=/path/to/ts/

key_file=video.key
openssl rand 16 > $key_file
enc_key=$(hexdump -v -e '16/1 "%02x"' $key_file)

pushd $ts_dir

ts_cnt=$(ls *.ts | wc -l)
((ts_cnt--))

i=0
for i in $(seq -f "%01g" 0 $ts_cnt); do
    iv=$(printf '%032x' $i)
    ts_file=segment-$i.ts

    echo [$i] $ts_file

    openssl aes-128-cbc -e -in $ts_file -out encrypted_${ts_file} -nosalt -iv $iv -K $enc_key
done

popd
