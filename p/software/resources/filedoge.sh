cmdself=$0

if [ -z "$1" ]; then
	echo "Upload File: ${cmdself} -upload \"filepath\""
	echo "File Information: ${cmdself} -file \"token\""
	echo "Delete File: ${cmdself} -delete \"token\" \"delete_token\""
	echo "Download File: ${cmdself} -download \"Upload file log\""
	echo "Help: ${cmdself} --help"
fi  

# Upload File
if [ "$1" == "-upload" ]; then	  
	filePath=$2
	filePathName=$(echo "${filePath}" | tr '\/' ' ' | awk '{print $NF}')
	FileDogeLogDir="${HOME}/FileDoge/Log"	  
	log=${FileDogeLogDir}/${filePathName}/${filePathName}.txt.1
	if [ ! -d "${FileDogeLogDir}/${filePathName}" ]; then
		mkdir -p "${FileDogeLogDir}/${filePathName}"
	fi	  
	compile_size=$((200 * 1024 * 1024))
	compile_file_size=$(stat -c%s "${filePath}")
	if [ "${compile_file_size}" -ge "${compile_size}" ]; then
		split -d -b 199m ${filePath} ${filePath}_split_
		lookup_var=$(ls -l ${filePath}_split_* | sort -nr | nl | tail -n 1 | awk '{print $1}')
		if [ -f "${log}" ]; then
			if [ "${filePathName}_*.txt" ]; then
				flag=0
				flag=$(ls "${FileDogeLogDir}/${filePathName}/${filePathName}".txt.* | tail -n 1 | awk -F '.' '{print $NF}')
				log=${FileDogeLogDir}/${filePathName}/${filePathName}.txt.$((flag + 1))
			fi
		fi
		for ((i = 0; i < ${lookup_var}; i++))
		do
			lookup_num=$(printf "%02d\n" $i)
			curl --location --request POST 'https://api.filedoge.com/upload' -H "Content-Type: multipart/form-data;" --form "file=@${filePath}_split_${lookup_num}" | cat >> ${log} && echo "$(readlink -f ${log})" && cat ${log}
			echo "" >> ${log}
		done
	else
		if [ -f "${log}" ]; then
			flag=0
			flag=$(ls "${FileDogeLogDir}/${filePathName}/${filePathName}".txt.* | tail -n 1 | awk -F '.' '{print $NF}')
			log=${FileDogeLogDir}/${filePathName}/${filePathName}.txt.$((flag + 1))
		fi
		curl --location --request POST 'https://api.filedoge.com/upload' -H "Content-Type: multipart/form-data;" --form "file=@${filePath}" | cat >> ${log} && echo "$(readlink -f ${log})" && cat ${log}
		echo "" >> ${log}
	fi
fi

if [ "$1" == "-file" ] || [ "$1" == "-delete" ]; then
	token=$2
	# File Information
	if [ "$1" == "-file" ]; then
		curl --location --request GET "https://api.filedoge.com/info/${token}"
		# Delete File
	elif [ "$1" == "-delete" ]; then
		delete_token=$3
		curl --location --request POST "https://api.filedoge.com/delete/${token}/{$delete_token}"

	fi
fi
# Download File
if [ "$1" == "-download" ]; then
	multifile_token=$2
	multifile_token_num=$(cat ${multifile_token} | awk -F '"' '{print $4}' | nl | tail -n 1 | awk '{print $1}')
	if [ "${multifile_token_num}" == 1 ]; then
		token=$(cat ${multifile_token} | awk -F '"' '{print $4}')
		download_file_name=$(${cmdself} -file ${token} | tr ',' ' ' | tr ' ' '\n' | grep --color "originalFilename" | tr '"' ' ' | awk '{print $3}')
		download_file_url=$(${cmdself} -file ${token} | tr ',' ' ' | tr ' ' '\n' | grep --color "downloadUrl" | tr '"' ' ' | awk '{print $3}')
		FileDogeDownloadDir="${HOME}/FileDoge/Download/${download_file_name}"
		if [ ! -d "$FileDogeDownloadDir" ]; then
			mkdir -p ${FileDogeDownloadDir}
		fi
		wget -P ${FileDogeDownloadDir} ${download_file_url}		
		if [ -f "${FileDogeDownloadDir}/${download_file_name}" ]; then
			latest_file=$(ls "${FileDogeDownloadDir}/${download_file_name}".* 2>/dev/null | tail -n 1)
			if [ -n "${latest_file}" ]; then
				flag=0
				flag=$(ls "${FileDogeDownloadDir}/${download_file_name}".* | tail -n 1 | awk -F '.' '{print $NF}')
				mv -v ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}.$((flag + 1))
			else
				mv -v  ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}.$((flag + 1))
			fi
		else
			mv -v ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}			  
		fi
	elif [ "${multifile_token_num}" -gt "1" ]; then
		filePath=$2
		catFileName=$(cat ${filePath} | sed -n "1"p | awk -F '"' '{print $14}' | awk -F '_' '{print $1}')
		splitFileName=$(cat ${filePath} | sed -n "1"p | awk -F '"' '{print $14}' | tr -d '0-9')
		for ((i = 1; i <= ${multifile_token_num}; i++))
		do
			token=$(cat ${multifile_token} | awk -F '"' '{print $4}' | nl | sed -n "${i}"p | awk '{print $2}')	  
			download_file_name=$(${cmdself} -file ${token} | tr ',' ' ' | tr ' ' '\n' | grep --color "originalFilename" | tr '"' ' ' | awk '{print $3}')
			download_file_url=$(${cmdself} -file ${token} | tr ',' ' ' | tr ' ' '\n' | grep --color "downloadUrl" | tr '"' ' ' | awk '{print $3}')
			FileDogeDownloadDir="${HOME}/FileDoge/Download/${catFileName}"
			if [ ! -d "$FileDogeDownloadDir" ]; then
				mkdir -p ${FileDogeDownloadDir}
			fi
			wget -P ${FileDogeDownloadDir} ${download_file_url}			
			if [ -f "${FileDogeDownloadDir}/${download_file_name}" ]; then
				latest_file=$(ls "${FileDogeDownloadDir}/${download_file_name}".* 2>/dev/null | tail -n 1)
				if [ -n "${latest_file}" ]; then
					flag=0
					flag=$(ls "${FileDogeDownloadDir}/${download_file_name}".* | tail -n 1 | awk -F '.' '{print $NF}')
					mv -v ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}.$((flag + 1))
				else
					mv -v ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}.$((flag + 1))
				fi
			else
				mv -v ${FileDogeDownloadDir}/${token} ${FileDogeDownloadDir}/${download_file_name}

			fi
		done
		if [ -f "${FileDogeDownloadDir}/${catFileName}" ]; then			  
			rm -rf "${FileDogeDownloadDir}/${catFileName}"
		fi
		for ((i = 0; i < multifile_token_num; i++))
		do
			lookup_num=$(printf "%02d\n" $i)
			cat ${FileDogeDownloadDir}/${splitFileName}$(printf "%02d" $((lookup_num))) >> ${FileDogeDownloadDir}/${catFileName}
		done
	fi
fi

if [ "$1" == "--help" ] && [ -z "$2" ]; then
	echo "File Doge API"
	echo "File Doge offers a free and unmetered API to upload and generate download links for files up to 200mb in size, although we do not guarantee that the API remain free or unmetered in the future"
	echo ""
	echo ""
	echo "Upload File"
	echo "You will send us a file with POST request with a size less than 200mb"
	echo "curl --location --request POST 'https://api.filedoge.com/upload' -H \"Content-Type: multipart/form-data;\" --form 'file=@filePath'"
	echo "Successfull Response"
	echo "{"
	echo "	token: fileToken,"
	echo "	"name": fileName,"
	echo "	"size": fileSizeInBytes,"
	echo "	"originalFilename": originalFilename,"
	echo "	"createdAt": creationDate,"
	echo "	"mimeType": fileMimeType"
	echo "	"deleteToken": fileDeleteToken"
	echo "}"
	echo ""
	echo ""
	echo "File Information"
	echo ""
	echo "You will send us a file token with GET request to get information"
	echo "curl --location --request GET 'https://api.filedoge.com/info/TOKEN'"
	echo "Successfull Response"
	echo "{"
	echo "	token: fileToken,"
	echo "	"name": fileName,"
	echo "	"size": fileSizeInBytes,"
	echo "	"originalFilename": originalFilename,"
	echo "	"createdAt": creationDate,"
	echo "	"mimeType": fileMimeType"
	echo "	"downloadUrl": directUrlToDownloadFile"
	echo "}"
	echo ""
	echo ""
	echo "Delete File"
	echo "You can delete your files using the file token and delete identifier"
	echo "curl --location --request POST 'https://api.filedoge.com/delete/\$TOKEN/\$DELETE_TOKEN'"
	echo "Successfull Response"
	echo "{"
	echo "	messgae: "File Deleted Successfully","
	echo "}"
	echo ""
	echo ""
	echo "Errors"
	echo "If you or us encounter an error we respond with 200 OK and a JSON which is specify what's went wrong"
	echo "Error Example"
	echo "{"
	echo "	error: errorMessage,"
	echo "}"
fi
