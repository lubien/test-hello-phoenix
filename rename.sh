#!/bin/sh

name=`basename *`
mv $name/bin/$name $name/bin/app
mv $name app
