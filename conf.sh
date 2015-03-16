#!/bin/bash

#####
# Configuration values for log ingestion website
#####

# Port the data collection site will run on:
port=81
# Username the data will be stored under in HDFS:
hadoopuser=hue
# Name of the data collection site
# DO NOT USE SPECIAL CHARACTERS IN THIS
sitetitle="Sample Site"
# Friendly description of the site:
sitedesc="An example site for showing log ingestion in HDP"
# There will be two categories, each with three buttons:
category1="Clothes"
c1btn1="Shoes"
c1btn2="Hats"
c1btn3="Coats"
category2="Shipping method"
c2btn1="Planes"
c2btn2="Trains"
c2btn3="Automobiles"