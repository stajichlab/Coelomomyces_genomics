#!/bin/bash
#SBATCH --nodes 1 --ntasks 16 --mem 96G -J CoelAAFTF --out logs/AAFTF.%a.log -p intel --time 7-0:0:0

hostname
MEM=196
CPU=$SLURM_CPUS_ON_NODE
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi

module load AAFTF

OUTDIR=input
SAMPLEFILE=samples.csv
STRAIN=$(tail -n +2 $SAMPLEFILE | sed -n ${N}p | cut -d, -f1)
BASE=$(tail -n +2 $SAMPLEFILE | sed -n ${N}p | cut -d, -f2)
PHYLUM=Blastocladiomycota
ASM=genomes

mkdir -p $ASM

if [ -z $CPU ]; then
    CPU=1
fi

ASMFILE=$ASM/${BASE}.spades.fasta
WORKDIR=working_AAFTF
VECCLEAN=$ASM/${BASE}.vecscreen.fasta
PURGE=$ASM/${BASE}.sourpurge.fasta
CLEANDUP=$ASM/${BASE}.rmdup.fasta
PILON=$ASM/${BASE}.pilon.fasta
SORTED=$ASM/${STRAIN}.sorted.fasta
STATS=$ASM/${BASE}.sorted.stats.txt
LEFTTRIM=$WORKDIR/${BASE}_1P.fastq.gz
RIGHTTRIM=$WORKDIR/${BASE}_2P.fastq.gz

LEFT=$WORKDIR/${BASE}_filtered_1.fastq.gz
RIGHT=$WORKDIR/${BASE}_filtered_2.fastq.gz

mkdir -p $WORKDIR

echo "$BASE"
if [ ! -f $ASMFILE ]; then    
    if [ ! -f $LEFT ]; then
	echo "$OUTDIR/${BASE}_R1.fq.gz $OUTDIR/${BASE}_R2.fq.gz"
	if [ ! -f $LEFTTRIM ]; then
	    AAFTF trim --method bbduk --memory $MEM --left $OUTDIR/${BASE}_R1.fq.gz --right $OUTDIR/${BASE}_R2.fq.gz -c $CPU -o $WORKDIR/${BASE}
	fi
	echo "$LEFTTRIM $RIGHTTRIM"
	AAFTF filter -c $CPU --memory $MEM -o $WORKDIR/${BASE} --left $LEFTTRIM --right $RIGHTTRIM --aligner bbduk 
	echo "$LEFT $RIGHT"
	if [ -f $LEFT ]; then
		unlink $LEFTTRIM
		unlink $RIGHTTRIM
	fi
    fi
    AAFTF assemble -c $CPU --left $LEFT --right $RIGHT  --memory $MEM \
	-o $ASMFILE -w $WORKDIR/spades_$BASE --spades_tmpdir /scratch/$USER
    
    if [ -s $ASMFILE ]; then
	rm -rf $WORKDIR/spades_${BASE}/K?? $WORKDIR/spades_${BASE}/tmp
    fi

    if [ ! -f $ASMFILE ]; then
	echo "SPADES must have failed, exiting"
	exit
    fi
fi

if [ ! -f $VECCLEAN ]; then
    AAFTF vecscreen -i $ASMFILE -c $CPU -o $VECCLEAN 
fi

if [ ! -f $PURGE ]; then
    AAFTF sourpurge -i $VECCLEAN -o $PURGE -c $CPU --phylum $PHYLUM --left $LEFT  --right $RIGHT
fi

if [ ! -f $CLEANDUP ]; then
   AAFTF rmdup -i $PURGE -o $CLEANDUP -c $CPU -m 500
fi

if [ ! -f $PILON ]; then
   AAFTF pilon -i $CLEANDUP -o $PILON -c $CPU --left $LEFT  --right $RIGHT
fi

if [ ! -f $PILON ]; then
    echo "Error running Pilon, did not create file. Exiting"
    exit
fi

if [ ! -f $SORTED ]; then
    AAFTF sort -i $PILON -o $SORTED
fi

if [ ! -f $STATS ]; then
    AAFTF assess -i $SORTED -r $STATS
fi
