package terratest

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestNetworkModule(t *testing.T) {
	t.Parallel()

	tfOptions := &terraform.Options{
		TerraformDir: filepath.Join("..", "..", "infra", "env", "dev"),
		NoColor:      true,
	}

	terraform.InitAndValidate(t, tfOptions)
}

