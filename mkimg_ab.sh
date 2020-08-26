#/bin/bash

LINEAGEVERSION=lineage-16.0
DATE=`date +%Y%m%d`
IMGNAME=$LINEAGEVERSION-$DATE-rpi4.img
IMGSIZE=6
OUTDIR=${ANDROID_PRODUCT_OUT:="../../../out/target/product/rpi4"}
IMGNAMEDIR=`pwd`

if [ `id -u` != 0 ]; then
	echo "Must be root to run script!"
	exit
fi

if [ -f $IMGNAME ]; then
	echo "File $IMGNAME already exists!"
else
	echo "Creating image file $IMGNAME..."
	dd if=/dev/zero of=$IMGNAME bs=512k count=$(echo "$IMGSIZE*1024*2" | bc)
	sync
	echo "Creating partitions..."
	(
	echo o
	echo n
	echo p
	echo 1
	echo
	echo +256M
	echo n
	echo p
	echo 2
	echo
	echo +1024M
	echo n
	echo p
	echo 3
	echo
	echo +256M
	echo n
	echo e
	echo
	echo
	echo n
	echo
	echo +1024M
	echo n
	echo
	echo +256M
	echo n
	echo
	echo +1M
	echo n
	echo
	echo
	echo t
	echo 1
	echo c
	echo a
	echo 1
	echo w
	) | fdisk $IMGNAME
	sync
	LOOPDEV=`kpartx -av $IMGNAME | awk 'NR==1{ sub(/p[0-9]$/, "", $3); print $3 }'`
	sync
	if [ -z "$LOOPDEV" ]; then
		echo "Unable to find loop device!"
		kpartx -d $IMGNAME
		exit
	fi
	echo "Image mounted as $LOOPDEV"
	sleep 5
	mkfs.fat -F 32 /dev/mapper/${LOOPDEV}p1
	mkfs.ext4 /dev/mapper/${LOOPDEV}p8
	resize2fs /dev/mapper/${LOOPDEV}p8 687868
#	mkfs.ext4 /dev/mapper/${LOOPDEV}p7
#	resize2fs /dev/mapper/${LOOPDEV}p7 687868
	echo "Copying system..."
	dd if=$OUTDIR/system.img of=/dev/mapper/${LOOPDEV}p2 bs=1M
	echo "Copying vendor..."
	dd if=$OUTDIR/vendor.img of=/dev/mapper/${LOOPDEV}p3 bs=1M
	echo "Copying system_b..."
	dd if=$OUTDIR/system.img of=/dev/mapper/${LOOPDEV}p5 bs=1M
	echo "Copying vendor_b..."
	dd if=$OUTDIR/vendor.img of=/dev/mapper/${LOOPDEV}p6 bs=1M
	echo "Copying misc..."
	dd if=misc.bin of=/dev/mapper/${LOOPDEV}p7 bs=1M
	echo "Copying boot..."
	mkdir -p sdcard/boot
	sync
	mount /dev/mapper/${LOOPDEV}p1 sdcard/boot
	sync
	cp boot/* sdcard/boot
	cp boot/config_ab.txt sdcard/boot/config.txt
	cp ../../../vendor/brcm/rpi4/proprietary/boot/* sdcard/boot
	cp $OUTDIR/obj/KERNEL_OBJ/arch/arm/boot/zImage sdcard/boot
	cp $OUTDIR/obj/KERNEL_OBJ/arch/arm/boot/zImage sdcard/boot/zImage_b
	cp -R $OUTDIR/obj/KERNEL_OBJ/arch/arm/boot/dts/* sdcard/boot
	cp $OUTDIR/ramdisk.img sdcard/boot
	cp $OUTDIR/ramdisk.img sdcard/boot/ramdisk_b.img
	mkimage -A arm -T script -C none -n "Boot script" -d rpi4-bootscript.txt sdcard/boot/boot.scr
#	mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n "Linux kernel" -d zImage uImage
	cp u-boot.bin sdcard/boot
	sync
	umount /dev/mapper/${LOOPDEV}p1
	rm -rf sdcard
	kpartx -d $IMGNAME
	sync
	echo "Done, created $IMGNAME!"

	cd $OUTDIR
	tar -cvf ${IMGNAMEDIR}/install.img ramdisk.img system.img vendor.img 
	cd -

	cd boot/
	tar -rvf ${IMGNAMEDIR}/install.img *
	cd -

	cd $OUTDIR/obj/KERNEL_OBJ/arch/arm/boot/
	tar -rvf ${IMGNAMEDIR}/install.img zImage
	cd -
fi
