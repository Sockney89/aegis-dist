# Design by contract

Contracts are first-class: every function may declare a precondition and a
postcondition. The compiler carries them into the generated binary, which checks
them at runtime. A violated contract aborts with a diagnostic such as:

```
AEGIS ASSERT FAILED: BankAccount.deposit: requires failed
```

```aegis
impl BankAccount {
    requires amount > 0
    ensures self.balance == old(self.balance) + amount
    fn deposit(mut self, amount: Int) -> Result[Empty, Error] {
        self.balance = self.balance + amount
        return ok
    }
}
```

`old(expr)` inside an `ensures` clause is evaluated before the body runs and
substituted into the postcondition, which is checked after the body. This
turns "what must be true here and now" into something the runtime can verify,
which is especially valuable for machine-and-human co-authoring: the contract
is executable documentation.

Contracts are also used at the call boundary inside the standard library to
express invariants that callers must respect, e.g. `Stack.pop` requires
`!self.is_empty()`.