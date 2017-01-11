#!/sbin/sh

# Validate that the incoming OTA is compatible with an already-installed
# system

testkey="308204a830820390a003020102020900936eacbe07f201df300d06092a864886f70d0101050500308194310b3009060355040613025553311330110603550408130a43616c69666f726e6961311630140603550407130d4d6f756e7461696e20566965773110300e060355040a1307416e64726f69643110300e060355040b1307416e64726f69643110300e06035504031307416e64726f69643122302006092a864886f70d0109011613616e64726f696440616e64726f69642e636f6d301e170d3038303232393031333334365a170d3335303731373031333334365a308194310b3009060355040613025553311330110603550408130a43616c69666f726e6961311630140603550407130d4d6f756e7461696e20566965773110300e060355040a1307416e64726f69643110300e060355040b1307416e64726f69643110300e06035504031307416e64726f69643122302006092a864886f70d0109011613616e64726f696440616e64726f69642e636f6d30820120300d06092a864886f70d01010105000382010d00308201080282010100d6931904dec60b24b1edc762e0d9d8253e3ecd6ceb1de2ff068ca8e8bca8cd6bd3786ea70aa76ce60ebb0f993559ffd93e77a943e7e83d4b64b8e4fea2d3e656f1e267a81bbfb230b578c20443be4c7218b846f5211586f038a14e89c2be387f8ebecf8fcac3da1ee330c9ea93d0a7c3dc4af350220d50080732e0809717ee6a053359e6a694ec2cb3f284a0a466c87a94d83b31093a67372e2f6412c06e6d42f15818dffe0381cc0cd444da6cddc3b82458194801b32564134fbfde98c9287748dbf5676a540d8154c8bbca07b9e247553311c46b9af76fdeeccc8e69e7c8a2d08e782620943f99727d3c04fe72991d99df9bae38a0b2177fa31d5b6afee91f020103a381fc3081f9301d0603551d0e04160414485900563d272c46ae118605a47419ac09ca8c113081c90603551d230481c13081be8014485900563d272c46ae118605a47419ac09ca8c11a1819aa48197308194310b3009060355040613025553311330110603550408130a43616c69666f726e6961311630140603550407130d4d6f756e7461696e20566965773110300e060355040a1307416e64726f69643110300e060355040b1307416e64726f69643110300e06035504031307416e64726f69643122302006092a864886f70d0109011613616e64726f696440616e64726f69642e636f6d820900936eacbe07f201df300c0603551d13040530030101ff300d06092a864886f70d010105050003820101007aaf968ceb50c441055118d0daabaf015b8a765a27a715a2c2b44f221415ffdace03095abfa42df70708726c2069e5c36eddae0400be29452c084bc27eb6a17eac9dbe182c204eb15311f455d824b656dbe4dc2240912d7586fe88951d01a8feb5ae5a4260535df83431052422468c36e22c2a5ef994d61dd7306ae4c9f6951ba3c12f1d1914ddc61f1a62da2df827f603fea5603b2c540dbd7c019c36bab29a4271c117df523cdbc5f3817a49e0efa60cbd7f74177e7a4f193d43f4220772666e4c4d83e1bd5a86087cf34f2dec21e245ca6c2bb016e683638050d2c430eea7c26a1c49d3760a58ab7f1a82cc938b4831384324bd0401fa12163a50570e684d"

grep -q "Command:.*\"--wipe\_data\"" /tmp/recovery.log
if [ $? -eq 0 ]; then
  echo "Data will be wiped after install; skipping signature check..."
  exit 0
fi

grep -q "Command:.*\"--headless\"" /tmp/recovery.log
if [ $? -eq 0 ]; then
  echo "Headless mode install; skipping signature check..."
  exit 0
fi

if [ -f "/data/system/packages.xml" -a -f "/tmp/releasekey" ]; then
  relkey=$(cat "/tmp/releasekey")
  OLDIFS="$IFS"
  IFS=""
  while read line; do
    if [ "${#line}" -gt 4094 ]; then
      continue
    fi
    params=${line# *<package *}
    if [ "$line" != "$params" ]; then
      kvp=${params%% *}
      params=${params#* }
      while [ "$kvp" != "$params" ]; do
        key=${kvp%%=*}
        val=${kvp#*=}
        vlen=$(( ${#val} - 2 ))
        val=${val:1:$vlen}
        if [ "$key" = "name" ]; then
          package="$val"
        fi
        kvp=${params%% *}
        params=${params#* }
      done
      continue
    fi
    params=${line# *<cert *}
    if [ "$line" != "$params" ]; then
      keyidx=""
      keyval=""
      kvp=${params%% *}
      params=${params#* }
      while [ "$kvp" != "$params" ]; do
        key=${kvp%%=*}
        val=${kvp#*=}
        vlen=$(( ${#val} - 2 ))
        val=${val:1:$vlen}
        if [ "$key" = "index" ]; then
          keyidx="$val"
        fi
        if [ "$key" = "key" ]; then
          keyval="$val"
        fi
        kvp=${params%% *}
        params=${params#* }
      done
      if [ -n "$keyidx" ]; then
        if [ "$package" = "com.android.htmlviewer" ]; then
          cert_idx="$keyidx"
        fi
      fi
      if [ -n "$keyval" ]; then
        eval "key_$keyidx=$keyval"
      fi
      continue
    fi
  done < "/data/system/packages.xml"
  IFS="$OLDIFS"

  # Tools missing? Err on the side of caution and exit cleanly
  if [ -z "$cert_idx" ]; then
    echo "Package cert index not found; skipping signature check..."
    exit 0
  fi

  varname="key_$cert_idx"
  eval "pkgkey=\$$varname"

  if [ "$pkgkey" != "$relkey" -a "$pkgkey" != "$testkey" ]; then
     echo "You have an installed system that isn't signed with this build's key, aborting..."
     exit 124
  fi
fi

exit 0
