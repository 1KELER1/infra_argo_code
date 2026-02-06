terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }

  required_version = ">=1.14.3"
}


data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

provider "aws" {
  region = var.aws_region
}



provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_subnet" "private_zone_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/19"
  # исользование преффикса a  для региона под вопросом
  availability_zone = var.aws_region != "" ? "${var.aws_region}a" : null

  tags = {
    Name                     = "${var.cluster_name}-private-subnet"
    "kubernetes.io/role/elb" = "1"
    # не обезательно, но рекомендуется для автоматического обнаружения кластера
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "private_zone_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.32.0/19"
  # исользование преффикса a  для региона под вопросом
  availability_zone = var.aws_region != "" ? "${var.aws_region}b" : null
  tags = {
    Name                     = "${var.cluster_name}-private-subnet"
    "kubernetes.io/role/elb" = "1"
    # не обезательно, но рекомендуется для автоматического обнаружения кластера
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "public_zone_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = var.aws_region != "" ? "${var.aws_region}a" : null
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-subnet"
    "kubernetes.io/role/elb" = "1"
    # не обезательно, но рекомендуется для автоматического обнаружения кластера
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "public_zone_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = var.aws_region != "" ? "${var.aws_region}b" : null
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-subnet"
    "kubernetes.io/role/elb" = "1"
    # не обезательно, но рекомендуется для автоматического обнаружения кластера
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}


resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone_a.id

  tags = {
    Name = "${var.cluster_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}



resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }


  tags = {
    Name = "${var.cluster_name}-private-rt"
  }

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id

  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }

}

resource "aws_route_table_association" "private_zone_a" {
  subnet_id      = aws_subnet.private_zone_a.id
  route_table_id = aws_route_table.private.id


}

resource "aws_route_table_association" "private_zone_b" {
  subnet_id      = aws_subnet.private_zone_b.id
  route_table_id = aws_route_table.private.id

}


resource "aws_route_table_association" "public_zone_a" {
  subnet_id      = aws_subnet.public_zone_a.id
  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "public_zone_b" {
  subnet_id      = aws_subnet.public_zone_b.id
  route_table_id = aws_route_table.public.id

}
