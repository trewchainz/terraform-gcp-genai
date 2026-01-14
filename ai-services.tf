# Vertex AI configuration
resource "google_vertex_ai_index" "vector_index" {
  region       = var.region
  display_name = "${var.application_name} Vector Index"
  description  = "Vector index for RAG application"

  metadata {
    contents_delta_uri = "gs://${google_storage_bucket.rag_documents.name}/embeddings/"
    config {
      dimensions = 768
      algorithm_config {
        tree_ah_config {
          leaf_node_embedding_count    = 500
          leaf_nodes_to_search_percent = 7
        }
      }
    }
  }
}

# Enable required APIs
resource "google_project_service" "aiplatform" {
  service = "aiplatform.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "alloydb" {
  service = "alloydb.googleapis.com"

  disable_on_destroy = false
}
