make

./sol-codegen < $1
cp iloc.out iloc.out.bak
./codegen < $1

sed -i 's|//.*||g' iloc.out
awk 'NF' iloc.out > temp_dat
mv temp_dat iloc.out

sed -i 's|//.*||g' iloc.out.bak
awk 'NF' iloc.out.bak > temp_dat
mv temp_dat iloc.out.bak

printf "\n-----Begin Difference Testing!-----\n\n"
diff iloc.out iloc.out.bak
printf "\n------End Difference Testing!------\n"

printf "\n-----SIM Test: solution-----\n"
/ilab/users/uli/cs415/spring18/ILOC_Simulator/sim < iloc.out.bak

printf "\n-----SIM Test: custom-------\n"
/ilab/users/uli/cs415/spring18/ILOC_Simulator/sim < iloc.out

make clean
rm iloc.out.bak
