#!/bin/bash

# Load necessary modules
module purge
module load gcc/8.2.0
module load python/anaconda3.10-2022.10
source activate deeptools

# Define constants
BLACKLIST="/bgfs/ialdiri/Genomes/mm10-blacklist.v2.bed.gz" # mm10 (PLUTO FILES)
CHROM_SIZE="2650000000"
WINDOW_SIZE=10

# Define paths for SOX2 CR Files
SOX2_BAM_DIR="/bgfs/ialdiri/CR-ChIP/Sox2CR/results/02_alignment/bowtie2/target/dedup"
SOX2_BIGWIG_DIR="/bgfs/ialdiri/CR-ChIP/bamCovBW/SOX2"
SOX2_BAM_FILES=("SOX2_S1_R1.target.dedup.sorted.bam" "SOX2_S3_R1.target.dedup.sorted.bam") 

# Define paths for VSX2 ChIP Files
VSX2_BAM_DIR="/bgfs/ialdiri/CR-ChIP/VSX2_Chip-Seq/outDir/bowtie2/mergedLibrary"
VSX2_BIGWIG_DIR="/bgfs/ialdiri/CR-ChIP/bamCovBW/VSX2"
VSX2_BAM_FILES=("Vsx2_Sample1.mLb.clN.sorted.bam" "Vsx2_Sample3.mLb.clN.sorted.bam") 

mkdir -p $SOX2_BIGWIG_DIR
mkdir -p $VSX2_BIGWIG_DIR

# Generate bigWig files for each TF

# SOX2
for BAM in "${SOX2_BAM_FILES[@]}"; do
    SAMPLE_NAME=$(basename "$BAM" | basename "$BAM" | cut -d. -f1)
    bamCoverage \
        --bam "$SOX2_BAM_DIR/$BAM" \
        --outFileName "$SOX2_BIGWIG_DIR/${SAMPLE_NAME}.bigWig" \
        --binSize $WINDOW_SIZE \
        --normalizeUsing RPGC \
        --effectiveGenomeSize $CHROM_SIZE \
        --ignoreForNormalization chrX \
        --blackListFileName $BLACKLIST \
        --numberOfProcessors max \
        --verbose\
        --extendReads
done

# VSX2
for BAM in "${VSX2_BAM_FILES[@]}"; do
    SAMPLE_NAME=$(basename "$BAM" | basename "$BAM" | cut -d. -f1)
    bamCoverage \
        --bam "$VSX2_BAM_DIR/$BAM" \
        --outFileName "$VSX2_BIGWIG_DIR/${SAMPLE_NAME}.bigWig" \
        --binSize $WINDOW_SIZE \
        --normalizeUsing RPGC \
        --effectiveGenomeSize $CHROM_SIZE \
        --ignoreForNormalization chrX \
        --blackListFileName $BLACKLIST \
        --numberOfProcessors max \
        --verbose 
done

# Generate profilePlots for SOX2 

BIGWIG_FILES=("$SOX2_BIGWIG_DIR/SOX2_S1_R1.bigWig" "$SOX2_BIGWIG_DIR/SOX2_S3_R1.bigWig")
PEAKS_DIR="/bgfs/ialdiri/CR-ChIP/Peaks"

computeMatrix reference-point --referencePoint center -b 2000 -a 2000 \
    -S "${BIGWIG_FILES[@]}" \
    -R "$PEAKS_DIR/shared.bed" "$PEAKS_DIR/sox2_unique.bed" "$PEAKS_DIR/vsx2_9k_unique.bed" \
    -o "Sox2_Profile_matrix.gz" \
    --sortRegions descend \
    --sortUsing mean \
    --missingDataAsZero \
    --verbose -p max --skipZeros --smartLabels

# Fig 5G
plotProfile -m Sox2_Profile_matrix.gz \
    -out Sox2_Binding_profilePlot.png \
    --plotType lines \
    --dpi 600 \

plotProfile -m Sox2_Profile_matrix.gz \
    -out Sox2_Binding_profilePlot_Heatmap.png \
    --plotType heatmap \
    --dpi 600 \
    --colors RdBu_r \
    --yMax 20 \
    --regionsLabel "Shared (n = 1078)" "Sox2 Only (n = 2423)" "Vsx2 Only (n = 8028)"

#=========== VSX2 ===========
# Generate profilePlots for Vsx2 Samples

VSX2_BIGWIG_FILES=("$VSX2_BIGWIG_DIR/Vsx2_Sample1.bigWig" "$VSX2_BIGWIG_DIR/Vsx2_Sample3.bigWig")
PEAKS_DIR="/bgfs/ialdiri/CR-ChIP/Peaks"

computeMatrix reference-point --referencePoint center -b 2000 -a 2000 \
    -S "${VSX2_BIGWIG_FILES[@]}" \
    -R "$PEAKS_DIR/sox2_vsx2_9k_shared.bed" "$PEAKS_DIR/sox2_unique.bed" "$PEAKS_DIR/vsx2_9k_unique.bed" \
    --binSize $WINDOW_SIZE \
    -o "Vsx2_Profile_matrix.gz" \
    --sortRegions descend \
    --sortUsing mean \
    --missingDataAsZero \
    --verbose -p max --skipZeros --smartLabels

# Fig 5F
plotProfile -m Vsx2_Profile_matrix.gz \
    -out Vsx2_Binding_profilePlot.png \
    --plotType lines \
    --dpi 600 \

plotProfile -m Vsx2_Profile_matrix.gz \
    -out Vsx2_Binding_profilePlot_Heatmap.png \
    --plotType heatmap \
    --dpi 600 \
    --colors RdBu_r \
    --yMax 20 \
    --regionsLabel "Shared (n = 1078)" "Sox2 Only (n = 2423)" "Vsx2 Only (n = 8028)"

# Tornado Plot with both TFs

BIGWIG_FILES=("$SOX2_BIGWIG_DIR/SOX2_S1_R1.bigWig" "$VSX2_BIGWIG_DIR/Vsx2_Sample3.bigWig")
computeMatrix reference-point --referencePoint center -b 2000 -a 2000 \
    -S "${BIGWIG_FILES[@]}" \
    -R "$PEAKS_DIR/sox2_vsx2_9k_shared.bed" "$PEAKS_DIR/sox2_unique.bed" "$PEAKS_DIR/vsx2_9k_unique.bed" \
    --binSize $WINDOW_SIZE \
    -o "Fig5_tornado_matrix.gz" \
    --sortRegions descend \
    --sortUsing mean \
    --missingDataAsZero \
    --verbose -p max --skipZeros --smartLabels

# Fig 5A
plotHeatmap -m Fig5_tornado_matrix.gz -out SOX2_VSX2_Tornado.png \
    --colorMap 'Blues' \
    --verbose \
    -T "SOX2 VSX2 Tornado" \
    --regionsLabel "Shared (1078)" "Sox2 Only (2423)" "Vsx2 Only (8028)" \
    -x "" \
    --averageTypeSummaryPlot mean \
    --dpi 600 --legendLocation none