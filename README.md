# Open Source AI Hosting and Testing

This project aims to make it straightforward to launch an open model on cloud GPU infrastructure, run it behind a familiar API, and use it for tasks such as evaluation, benchmarking, customization, fine-tuning, and data-sovereignty experiments.

The first implementation targets AWS infrastructure. The longer-term goal is to support a range of high-level models and use cases, rather than one provider, model family, or hosted AI product.

## Current status

**Early AWS prototype.** The Terraform configuration currently:

- Provisions a GPU EC2 instance using an AWS Deep Learning AMI.
- Starts vLLM in Docker with a Hugging Face model (currently `Qwen/Qwen3-8B`).
- Keeps the model API off the public network and provides an AWS Systems Manager (SSM) port-forwarding command.
- Configures the vLLM server to expose its OpenAI-compatible API on port 8000.

This is a starting point, not a production-ready hosting service. Supported models depend on the serving engine and available GPU memory. Authentication at the model API, multi-user access, durable model storage, automated cleanup, and deployment validation are not implemented yet.

## Getting started

You need Terraform, AWS CLI credentials with permission to create the configured resources, and access to an AWS region with the selected GPU instance type available. The EC2 instance must be able to reach AWS Systems Manager and download the model and container image.

From the repository directory:

```sh
terraform init
terraform apply
```

Terraform prints an instance ID and a `port_forward_command`. Run that command in a separate terminal to forward local port 8000 to the instance. After the server has started and downloaded the model, send a request from another terminal:

```sh
curl http://localhost:8000/v1/models
```

For example, make a chat completion request:

```sh
curl http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-8B","messages":[{"role":"user","content":"Hello"}]}'
```

When finished, remove the resources with:

```sh
terraform destroy
```

GPU instances can incur substantial charges while running. Check AWS pricing and quota availability for your chosen region and instance type before applying, and destroy the instance when it is no longer needed. Terraform state may contain infrastructure identifiers; keep local state files private.

## Configuration

The current Terraform inputs are declared in [`main.tf`](main.tf):

| Input | Default | Purpose |
| --- | --- | --- |
| `region` | `us-east-1` | AWS region |
| `instance_type` | `g6.xlarge` | GPU EC2 instance type |
| `model` | `Qwen/Qwen3-8B` | Hugging Face model ID passed to vLLM |

Override a value with Terraform's `-var` option, for example `terraform apply -var="model=org/model-name"`. Gated Hugging Face models need an authorized download method; the current configuration does not set a Hugging Face token.

## Direction

The project is being developed in small, validated layers:

1. Provision and access one AWS GPU instance.
2. Start a model server and verify its API.
3. Improve configuration, observability, and lifecycle handling.
4. Add security and deployment options for broader use.
5. Explore evaluation, fine-tuning, and additional providers based on need.

These are areas of exploration, not promised features or a fixed roadmap. See the repository owner's private design notes for current decisions and open questions; those notes are intentionally not committed.

## Contributing

Issues and pull requests are welcome. Please include the use case and cloud costs or security implications relevant to proposed infrastructure changes. Avoid committing credentials, Terraform state, or private design notes.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full text. The license applies to this repository's code and documentation; models, model weights, container images, and cloud services may have separate terms.
