# DistributedOperations.jl

| **Documentation** | **Action Statuses** |
|:---:|:---:|
| [![][docs-dev-img]][docs-dev-url] [![][docs-stable-img]][docs-stable-url] | [![][doc-build-status-img]][doc-build-status-url] [![][build-status-img]][build-status-url] [![][code-coverage-img]][code-coverage-results] |

Fast parallel broadcast and reduction operations for Julia using binary-tree
algorithms.  DistributedOperations.jl can broadcast and reduce over any Julia
type, but we provide convenience methods for performing these operations on
Julia arrays.

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://chevronetc.github.io/DistributedOperations.jl/dev/

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://ChevronETC.github.io/DistributedOperations.jl/stable

[doc-build-status-img]: https://github.com/ChevronETC/DistributedOperations.jl/workflows/Documentation/badge.svg
[doc-build-status-url]: https://github.com/ChevronETC/DistributedOperations.jl/actions?query=workflow%3ADocumentation

[build-status-img]: https://github.com/ChevronETC/DistributedOperations.jl/workflows/Tests/badge.svg
[build-status-url]: https://github.com/ChevronETC/DistributedOperations.jl/actions?query=workflow%3A"Tests"

[code-coverage-img]: https://codecov.io/gh/ChevronETC/DistributedOperations.jl/branch/master/graph/badge.svg
[code-coverage-results]: https://codecov.io/gh/ChevronETC/DistributedOperations.jl