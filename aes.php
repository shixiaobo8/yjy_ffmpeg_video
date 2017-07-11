<?php
/**
 * AES128加解密类
 * @author dy
 *
 */
//defined('InEjbuy') or exit('Access Invalid!');
class Aes{
    //密钥
    private $_secrect_key;
      
    public function __construct(){
        $this->_secrect_key = '1234567812345678';
    }
    /**
     * 加密方法
     * @param string $str
     * @return string
     */
    public function encrypt($str){
        //AES, 128 ECB模式加密数据
        $screct_key = $this->_secrect_key;
        //$screct_key = base64_decode($screct_key);
        //$str = trim($str);
        $str = $this->addPKCS7Padding($str);
        //$iv = mcrypt_create_iv(mcrypt_get_iv_size(MCRYPT_RIJNDAEL_128,MCRYPT_MODE_ECB),MCRYPT_RAND);
		$iv = '5efd3f6060e20330';
        //$encrypt_str =  mcrypt_encrypt(MCRYPT_RIJNDAEL_128, $screct_key, $str, MCRYPT_MODE_ECB, $iv);
        $encrypt_str =  mcrypt_encrypt(MCRYPT_RIJNDAEL_128, $screct_key, $str, MCRYPT_MODE_CBC, $iv);
		return $encrypt_str;
        //return base64_encode($encrypt_str);
    }
      
    /**
     * 解密方法
     * @param string $str
     * @return string
     */
    public function decrypt($str){
        //AES, 128 ECB模式加密数据
        $screct_key = $this->_secrect_key;
        //$str = base64_decode($str);
        //$screct_key = base64_decode($screct_key);
        //$iv = mcrypt_create_iv(mcrypt_get_iv_size(MCRYPT_RIJNDAEL_128,MCRYPT_MODE_ECB),MCRYPT_RAND);
		$iv = '5efd3f6060e20330';
        //$encrypt_str =  mcrypt_decrypt(MCRYPT_RIJNDAEL_128, $screct_key, $str, MCRYPT_MODE_ECB, $iv);
        $encrypt_str =  mcrypt_decrypt(MCRYPT_RIJNDAEL_128, $screct_key, $str, MCRYPT_MODE_CBC, $iv);
        //$encrypt_str = trim($encrypt_str);
        $encrypt_str = $this->stripPKSC7Padding($encrypt_str);
        return $encrypt_str;
      
    }
      
    /**
     * 填充算法
     * @param string $source
     * @return string
     */
    function addPKCS7Padding($source){
        $source = trim($source);
        //$block = mcrypt_get_block_size('rijndael-128', 'ecb');
        $block = mcrypt_get_block_size('rijndael-128', 'cbc');
        $pad = $block - (strlen($source) % $block);
        if ($pad <= $block) {
            $char = chr($pad);
            $source .= str_repeat($char, $pad);
        }
        return $source;
    }
    /**
     * 移去填充算法
     * @param string $source
     * @return string
     */
    function stripPKSC7Padding($source){
        $source = trim($source);
        $char = substr($source, -1);
        $num = ord($char);
        if($num==62)return $source;
        $source = substr($source,0,-$num);
        return $source;
    }
}
/*
$aes = new Aes();
$str = file_get_contents('den11.ts');
$estr = $aes->encrypt($str);
file_put_contents('en11.ts',$estr);



$aes = new Aes();
$str = file_get_contents('jiamimyts.ts');
$estr = $aes->decrypt($str);
file_put_contents('den11.ts',$estr);
*/
if (empty($argv[1])) {
    echo '必须包含文件名参数'."\r\n";exit;
}
$aes = new Aes();
$str = file_get_contents($argv[1]);
$estr = $aes->encrypt($str);
$uniq = uniqid();
file_put_contents($uniq.'.ts',$estr);