#!/bin/sh
#
# Naive implementation of key management.
# it generates, encrypt and decrypt key file.
#

key_management_dependencies(){
    echo ""
}

key_management_generate_key_file(){
    decrypted_key_file_path=$1
    echo "test key" >> $decrypted_key_file_path
}


key_management_encrypt_key_file(){
    decrypted_key_file_path=$1
    encrypted_key_file_path=$2
    cp $decrypted_key_file_path $encrypted_key_file_path
}

key_management_decrypt_key_file(){
    encrypted_key_file_path=$1
    decrypted_key_file_path=$2
    cp $encrypted_key_file_path $decrypted_key_file_path
}