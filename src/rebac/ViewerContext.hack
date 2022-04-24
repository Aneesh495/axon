namespace Axon\ReBAC;

/**
 * ViewerContext encapsulates the identity, tenancy, and ambient security attributes
 * of the actor executing a graph query or mutation.
 */
final class ViewerContext {
  private ?string $userId;
  private ?string $tenantId;
  private vec<string> $roles;
  private dict<string, string> $attributes;
  private bool $isOmnipotent;

  public function __construct(
    ?string $userId = null,
    ?string $tenantId = null,
    vec<string> $roles = vec[],
    dict<string, string> $attributes = dict[],
    bool $isOmnipotent = false
  ) {
    $this->userId = $userId;
    $this->tenantId = $tenantId;
    $this->roles = $roles;
    $this->attributes = $attributes;
    $this->isOmnipotent = $isOmnipotent;
  }

  public function getUserId(): ?string {
    return $this->userId;
  }

  public function getTenantId(): ?string {
    return $this->tenantId;
  }

  public function getRoles(): vec<string> {
    return $this->roles;
  }

  public function getAttributes(): dict<string, string> {
    return $this->attributes;
  }

  public function isOmnipotent(): bool {
    return $this->isOmnipotent;
  }

  public function isAuthenticated(): bool {
    return $this->userId !== null;
  }

  public function toSubject(): Subject {
    if ($this->userId !== null) {
      return new Subject('user', $this->userId);
    }
    return new Subject('anonymous', 'guest');
  }

  /**
   * System viewer context with omnipotent bypass for internal operations and migrations.
   */
  public static function system(): ViewerContext {
    return new ViewerContext('system', 'system', vec['admin'], dict[], true);
  }

  /**
   * Anonymous guest context with zero elevated privileges.
   */
  public static function anonymous(): ViewerContext {
    return new ViewerContext(null, null, vec['guest'], dict[], false);
  }
}
