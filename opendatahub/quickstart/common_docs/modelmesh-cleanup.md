# Cleanup 

## Cleanup Quick Start

This will delete modelmesh and modelmesh test namespace(minio,pvc)
~~~
./cleanup.sh
~~~

## Cleanup all components 

This will delete modelmesh, modelmesh test namespace(minio,pvc) and nfs provisioner. If you want to try other quick start guide, please use above command.
~~~
C_FULL=true ./cleanup.sh
~~~
