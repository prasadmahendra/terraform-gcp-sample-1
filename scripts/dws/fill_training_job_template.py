
from jinja2 import Template
import argparse

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", type=str, required=True)
    parser.add_argument("--date", type=str, required=True)
    parser.add_argument("--job-name", type=str, required=True)
    return parser.parse_args()

if __name__ == "__main__":
    args = get_args()

    with open("training_job_template.yaml", "r") as fin:
        template = Template(fin.read())

    rendered_yaml = template.render(
        org_short_name=args.org,
        date=f'"{args.date}"',
        job_name=args.job_name,
    )

    with open("temp_training_job.yaml", "w") as fout:
        fout.write(rendered_yaml)