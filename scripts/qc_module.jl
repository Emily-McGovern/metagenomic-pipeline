#import Pkg
#Pkg.add("ArgParse")

using ArgParse

s = ArgParseSettings()
@add_arg_table s begin
    "--walltime", "-w"
    help = "Walltime hours"
    arg_type = Int
    default = 10
    "--mem", "-m"
    help = "mem Gb"
    arg_type = Int
    default = 10
    "--subs", "-s"
    help = "substitions"
    arg_type = Int
    default = 0
    "--threads", "-t"
    help = "threads - refer to clumpify.sh"
    arg_type = Int
    default = 4
    "--dupedist", "-d"
    help = "dupedist-refer to clumpify.sh"
    default = 12000
    arg_type = Int
    "--ref", "-r"
    help = "host reference"
    default = "/srv/scratch/mrcbio/humangenome/GRCh38_latest_genomic.fna"
    "input_dir"
        help = "input directory"
        required = true
    "output_dir"
        help = "input directory"
        required = true
end
parsed_args = parse_args(ARGS, s)

PBS_TEMPLATE = raw"""#!/bin/bash
#PBS -N {base_filename}_clumpify
#PBS -l nodes=1:ppn={threads}
#PBS -l walltime={walltime}:00:00
#PBS -l mem={mem}GB
#PBS -m ae
#PBS -M emily.mcgovern@unsw.edu.au

cd {input_dir}

module load java/8u45
module load bbmap/38.51
module load fastp/0.19.5
module load minimap2/2.16

unset _JAVA_OPTIONS
clumpify.sh in1={base_filename}_1.fastq in2={base_filename}_2.fastq out={base_filename}_1_clumpify.fastq out2={base_filename}_2_clumpify.fastq dedupe subs={subs} threads={threads} dupedist={dupedist}

fastp -i {base_filename}_1_clumpify.fastq -I {base_filename}_2_clumpify.fastq -o {base_filename}_qc_1.fastq -O {base_filename}_qc_2.fastq -h {base_filename}.outreport.html -p

minimap2 -c {ref} {base_filename}_qc_1.fastq {base_filename}_qc_2.fastq  > {base_filename}_out_mapping.paf

awk '{print $1}' {base_filename}_out_mapping.paf > {base_filename}_out_mapping.txt

filterbyname.sh  in1={base_filename}_qc_1.fastq \
 in2={base_filename}_qc_2.fastq \
 out1={base_filename}_clean_1.fastq \
 out2={base_filename}_clean_2.fastq \
 names={base_filename}_out_mapping.txt"""


output_pbs = PBS_TEMPLATE
for (key, value) in parsed_args
    global output_pbs
    output_pbs = replace(output_pbs, string("{", key, "}") => string(value))
end

base_files = []
    for filename in readdir(parsed_args["input_dir"])
        if endswith(filename, "_1.fastq")
            basefile = SubString(filename, 1, length(filename) - 8)
            push!(base_files, basefile)
        end
    end
    return base_files

for basefile in base_files
    constructed_pbs = replace(output_pbs, "{base_filename}" => basefile)
    open(string(parsed_args["output_dir"], basefile, ".pbs"), "w") do pbs_file
        write(pbs_file, constructed_pbs)
    end
end


